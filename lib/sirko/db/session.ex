defmodule Sirko.Db.Session do
  @moduledoc """
  This module provides methods for working with users' sessions stored in the graph
  as relations between pages (nodes represent pages).

  Each user visiting a site gets an unique session key.
  That key allows observing users' navigation between pages.
  """

  alias Sirko.{Neo4j, Entry}

  @type session_key :: Sirko.Session.session_key()

  @doc """
  Creates a session relation between 2 visited pages if it is
  a first transition between those pages during the current session.
  Otherwise, the relation will be updated to reflect a number of times
  the transition happened during the current session.

  If pages don't exist, they get created.
  """
  @spec track(session_key, entry :: Entry.t()) :: any
  def track(session_key, entry) do
    %Entry{
      referrer_path: referrer_path,
      current_path: current_path,
      assets: assets
    } = entry

    query = """
      MERGE (referrer:Page { path: {referrer_path} })

      MERGE (current:Page { path: {current_path} })
      SET current.assets = {assets}

      MERGE (referrer)-[s:SESSION { key: {key} }]->(current)
      ON CREATE SET s.occurred_at = timestamp(), s.count = 1
      ON MATCH SET s.occurred_at = timestamp(), s.count = s.count + 1
    """

    Neo4j.query(query, %{
      key: session_key,
      referrer_path: referrer_path,
      current_path: current_path,
      assets: assets
    })
  end

  @doc """
  A session is treated as expired when it is connected to the exit point. Therefore,
  this method iterates through the given list of session keys and creates relations between
  last visited pages and the exit point.
  """
  @spec expire(session_keys :: [session_key]) :: any
  def expire(session_keys) do
    query = """
      MATCH ()-[s:SESSION]->()
      WHERE s.key IN {keys}

      WITH s
      ORDER BY s.occurred_at

      WITH s.key AS key, last(collect(s)) AS last_hit

      WITH key, endNode(last_hit) AS last_page

      MERGE (exit:Page { exit: true })

      CREATE (last_page)-[new_s:SESSION]->(exit)
      SET new_s.key = key,
          new_s.expired_at = timestamp(),
          new_s.count = 1
    """

    Neo4j.query(query, %{keys: session_keys})
  end

  @doc """
  Returns true if a session relation with the given key exists and
  it isn't expired. Otherwise, false.
  """
  @spec active?(session_key) :: boolean
  def active?(session_key) do
    query = """
      MATCH ()-[s:SESSION { key: {key} }]->()
      RETURN (s.expired_at IS NULL) AS active
      ORDER BY s.occurred_at DESC
      LIMIT 1
    """

    case Neo4j.query(query, %{key: session_key}) do
      [%{"active" => active}] ->
        active

      _ ->
        false
    end
  end

  @doc """
  Returns a list of session keys which are inactive for the given number of milliseconds.
  """
  @spec all_inactive(time :: integer) :: [session_key]
  def all_inactive(time) do
    query = """
      MATCH ()-[s:SESSION]->()

      WITH s
      ORDER BY s.occurred_at

      WITH s.key AS key, last(collect(s)) AS last_hit
      WHERE last_hit.expired_at IS NULL AND timestamp() - last_hit.occurred_at > {time}

      RETURN collect(key) as keys
    """

    [%{"keys" => keys}] = Neo4j.query(query, %{time: time})

    keys
  end

  @doc """
  Returns a list of session keys which are expired for the given number of milliseconds.
  """
  @spec all_stale(time :: integer) :: [session_key]
  def all_stale(time) do
    query = """
      MATCH ()-[s:SESSION]->()
      WHERE timestamp() - s.expired_at > {time}
      RETURN collect(s.key) as keys
    """

    [%{"keys" => keys}] = Neo4j.query(query, %{time: time})

    keys
  end

  @doc """
  Removes sessions which are expired for the given number of milliseconds.
  """
  @spec remove_stale(time :: integer) :: any
  def remove_stale(time) do
    query = """
      MATCH ()-[s:SESSION]->()
      WHERE timestamp() - s.expired_at > {time}

      MATCH ()-[sess:SESSION {key: s.key}]->()
      DELETE sess
    """

    Neo4j.query(query, %{time: time})
  end
end
