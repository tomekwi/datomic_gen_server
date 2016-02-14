defmodule DatomicGenServer.Db do
  #TODO Use type Exdn.converter
  @type query_option :: DatomicGenServer.send_option | 
                        {:response_converter, (Exdn.exdn -> term)} | 
                        {:edn_tag_handlers, [{atom, Exdn.handler}, ...]}
  
  @type datom_map :: %{:e => integer, :a => atom, :v => term, :tx => integer, :added => boolean}
  @type transaction_result :: %{:"db-before" => %{:"basis-t" => integer}, 
                                :"db-after" => %{:"basis-t" => integer}, 
                                :"tx-data" => [datom_map], 
                                :tempids => %{integer => integer}}
  
  defmodule DatomicTransaction do
    defstruct basis_t_before: 0, 
              basis_t_after: 0, 
              added_datoms: [], 
              retracted_datoms: [], 
              tempids: %{} 
    @type t :: %DatomicTransaction{basis_t_before: integer, 
                                   basis_t_after: integer, 
                                   added_datoms: [Datom.t], 
                                   retracted_datoms: [Datom.t], 
                                   tempids: %{integer => integer}}
  end
  
  defmodule Datom do
    defstruct a: 0, e: 0, v: [], tx: %{}, added: false
    @type t :: %Datom{e: integer, a: atom, v: term, tx: integer, added: boolean}
  end

############################# INTERFACE FUNCTIONS  ############################
  @spec q(GenServer.server, [Exdn.exdn], [query_option]) :: {:ok, term} | {:error, term}
  def q(server_identifier, exdn, options \\ []) do
    case Exdn.from_elixir(exdn) do
      {:ok, edn_str} -> 
        case DatomicGenServer.q(server_identifier, edn_str, options) do
          {:ok, reply_str} -> convert_query_response(reply_str, options)
          error -> error
        end
      parse_error -> parse_error
    end
  end

  @spec transact(GenServer.server, [Exdn.exdn], [DatomicGenServer.send_option]) :: {:ok, DatomicTransaction.t} | {:error, term}
  def transact(server_identifier, exdn, options \\ []) do
    case Exdn.from_elixir(exdn) do
      {:ok, edn_str} -> 
        case DatomicGenServer.transact(server_identifier, edn_str, options) do          
          {:ok, reply_str} -> case Exdn.to_elixir(reply_str) do
              {:ok, exdn_result} -> transaction(exdn_result)
              error -> error
            end
          error -> error
        end
      parse_error -> parse_error
    end
  end
  
  @spec entity(GenServer.server, [Exdn.exdn], [atom] | :all, [query_option]) :: {:ok, term} | {:error, term}
  def entity(server_identifier, exdn, attr_names \\ :all, options \\ []) do
    case Exdn.from_elixir(exdn) do
      {:ok, edn_str} -> 
        case DatomicGenServer.entity(server_identifier, edn_str, attr_names, options) do          
          {:ok, reply_str} -> convert_query_response(reply_str, options)
          error -> error
        end
      parse_error -> parse_error
    end
  end

  @spec convert_query_response(String.t, [query_option]) :: {:ok, term} | {:error, term}
  defp convert_query_response(response_str, options) do
    converter = Keyword.get(options, :response_converter) || (fn x -> x end)
    handlers = Keyword.get(options, :edn_tag_handlers) || Exdn.standard_handlers
    Exdn.to_elixir(response_str, converter, handlers)
  end
  
############################# DATOMIC SHORTCUTS  ############################
  # Id/ident
  @spec dbid(atom) :: {:tag, :"db/id", [atom]} 
  def dbid(db_part) do
    {:tag, :"db/id", [db_part]}
  end

  @spec id :: :"db/id"
  def id, do: :"db/id"
  
  @spec ident :: :"db/ident"
  def ident, do: :"db/ident"

  # Transaction creation
  @spec add :: :"db/add"
  def add, do: :"db/add"
  
  @spec retract :: :"db/retract"
  def retract, do: :"db/retract"
  
  @spec install_attribute :: :"db.install/_attribute"
  def install_attribute, do:  :"db.install/_attribute"
  
  @spec alter_attribute :: :"db.alter/attribute"
  def alter_attribute, do: :"db.alter/attribute"
  
  @spec tx_instant :: :"db/txInstant"
  def tx_instant, do: :"db/txInstant"

  # Value types
  @spec value_type :: :"db/valueType"
  def value_type, do: :"db/valueType"
  
  @spec type_long :: :"db.type/long"
  def type_long, do: :"db.type/long"
  
  @spec type_keyword :: :"db.type/keyword"
  def type_keyword, do:  :"db.type/keyword"
  
  @spec type_string :: :"db.type/string"
  def type_string, do: :"db.type/string"
  
  @spec type_boolean :: :"db.type/boolean"
  def type_boolean, do: :"db.type/boolean"
  
  @spec type_bigint :: :"db.type/bigint"
  def type_bigint, do: :"db.type/bigint"
  
  @spec type_float :: :"db.type/float"
  def type_float, do: :"db.type/float"
  
  @spec type_double :: :"db.type/double"
  def type_double, do: :"db.type/double"
  
  @spec type_bigdec :: :"db.type/bigdec"
  def type_bigdec, do: :"db.type/bigdec"
  
  @spec type_ref :: :"db.type/ref"
  def type_ref, do: :"db.type/ref"
  
  @spec type_instant :: :"db.type/instant"
  def type_instant, do: :"db.type/instant"
  
  @spec type_uuid :: :"db.type/uuid"
  def type_uuid, do: :"db.type/uuid"
  
  @spec type_uri :: :"db.type/uri"
  def type_uri, do: :"db.type/uri"
  
  @spec type_bytes :: :"db.type/bytes"
  def type_bytes, do: :"db.type/bytes"

  # Cardinalities
  @spec cardinality :: :"db/cardinality"
  def cardinality, do: :"db/cardinality"
  
  @spec cardinality_one :: :"db.cardinality/one"
  def cardinality_one, do:  :"db.cardinality/one"
  
  @spec cardinality_many :: :"db.cardinality/many"
  def cardinality_many, do: :"db.cardinality/many"
  
  # Optional Schema Attributes  
  @spec doc :: :"db/doc"
  def doc, do: :"db/doc"
  
  @spec unique :: :"db/unique"
  def unique, do: :"db/unique"
  
  @spec unique_value :: :"db.unique/value"
  def unique_value, do: :"db.unique/value"
  
  @spec unique_identity :: :"db.unique/identity"
  def unique_identity, do: :"db.unique/identity"
  
  @spec index :: :"db/index"
  def index, do: :"db/index"
  
  @spec fulltext :: :"db/fulltext"
  def fulltext, do: :"db/fulltext"
  
  @spec is_component :: :"db/isComponent"
  def is_component, do: :"db/isComponent"
  
  @spec no_history :: :"db/noHistory"
  def no_history, do: :"db/noHistory"
  
  # Functions  
  @spec _fn :: :"db/fn"
  def _fn, do: :"db/fn"
  
  @spec fn_retract_entity :: :"db.fn/retractEntity"
  def fn_retract_entity, do: :"db.fn/retractEntity"
  
  @spec fn_cas :: :"db.fn/cas"
  def fn_cas, do: :"db.fn/cas"

  # Common partions
  @spec schema_partition :: :"db.part/db"
  def schema_partition, do: :"db.part/db"
  
  @spec transaction_partition :: :"db.part/tx"
  def transaction_partition, do: :"db.part/tx"
  
  @spec user_partition :: :"db.part/user"
  def user_partition, do: :"db.part/user"

  # Query placeholders
  # Symbol containing ? prefixed
  @spec q?(atom) :: {:symbol, atom }
  def q?(placeholder_atom) do
    variable_symbol = placeholder_atom |> to_string
    with_question_mark = "?" <> variable_symbol |> String.to_atom
    {:symbol, with_question_mark }
  end

  # Data sources
  # Implicit data source - $
  @spec implicit :: {:symbol, :"$"}
  def implicit, do: {:symbol, :"$"}
  
  # Symbol containing $ prefixed for data source specification
  @spec inS(atom) :: {:symbol, atom }
  def inS(placeholder_atom) do
    placeholder = placeholder_atom |> to_string
    with_dollar_sign = "$" <> placeholder |> String.to_atom
    {:symbol, with_dollar_sign }    
  end

  # Bindings and find specifications
  # For use in [:find ?e . :where [?e age 42] ]
  @spec single_scalar :: {:symbol, :"."}
  def single_scalar, do: {:symbol, :"."}

  # For use in [:find ?x :where [_ :likes ?x]]
  @spec blank_binding :: {:symbol, :"_"}
  def blank_binding, do: {:symbol, :"_"}

  # [?atom ...]
  @spec collection_binding(atom) :: [{:symbol, atom},...]
  def collection_binding(placeholder_atom) do
    [ q?(placeholder_atom), {:symbol, :"..."} ]
  end

  # Clauses - these functions keep us from having to sprinkle {:list ...} all over the place.
  @spec not_clause([Exdn.exdn]) :: {:list, [Exdn.exdn]}
  def not_clause(inner_clause), do: datomic_expression(:not, [inner_clause])

  @spec not_join_clause([{:symbol, atom},...], [Exdn.exdn]) :: {:list, [Exdn.exdn]}
  def not_join_clause(binding_list, inner_clause_list) do
    clauses_including_bindings = [ binding_list | inner_clause_list ]
    datomic_expression(:"not-join", clauses_including_bindings)
  end

  @spec or_clause([Exdn.exdn]) :: {:list, [Exdn.exdn]}
  def or_clause(inner_clauses), do: datomic_expression(:or, inner_clauses)

  # Only for use inside or clauses; `and` is the default otherwise.
  @spec and_clause([Exdn.exdn]) :: {:list, [Exdn.exdn]}
  def and_clause(inner_clauses), do: datomic_expression(:and, inner_clauses)

  @spec or_join_clause([{:symbol, atom},...], [Exdn.exdn]) :: {:list, [Exdn.exdn]}
  def or_join_clause(binding_list, inner_clause_list) do
    clauses_including_bindings = [ binding_list | inner_clause_list ]
    datomic_expression(:"or-join", clauses_including_bindings)
  end

  @spec pull_expression({:symbol, atom}, [Exdn.exdn]) :: {:list, [Exdn.exdn]}
  def pull_expression(entity_var, pattern_clauses) do
    datomic_expression(:pull, [entity_var, pattern_clauses])
  end

  # An expression clause is a Clojure list inside a vector.
  @spec expression_clause(atom, [Exdn.exdn]) :: [{:list, [Exdn.exdn]}]
  def expression_clause(function_symbol, remaining_expressions) do
    [ datomic_expression(function_symbol, remaining_expressions) ]
  end

  # An expression is a list starting with a symbol
  @spec datomic_expression(atom, [Exdn.exdn]) :: {:list, [Exdn.exdn]}
  defp datomic_expression(symbol_atom, remaining_expressions) do
    clause_list = [{:symbol, symbol_atom} | remaining_expressions ]
    {:list, clause_list}
  end

########## PRIVATE FUNCTIONS FOR STRUCTIFYING TRANSACTION RESPONSES #############
  @spec transaction(transaction_result) :: {:ok, DatomicTransaction.t} | {:error, term}
  defp transaction(transaction_result) do
    try do
      {added_datoms, retracted_datoms} = tx_data(transaction_result) |> to_datoms
      transaction_struct = %DatomicTransaction{
                              basis_t_before: basis_t_before(transaction_result), 
                              basis_t_after: basis_t_after(transaction_result), 
                              added_datoms: added_datoms, 
                              retracted_datoms: retracted_datoms, 
                              tempids: tempids(transaction_result)}
      {:ok, transaction_struct}
    rescue
      e -> {:error, e}
    end
  end
  
  @spec to_datoms([datom_map]) :: {[Datom.t], [Datom.t]}
  defp to_datoms(datom_maps) do
    datom_maps
    |> Enum.map(fn(datom_map) -> struct(Datom, datom_map) end) 
    |> Enum.partition(fn(datom) -> datom.added end)
  end
  
  @spec basis_t_before(%{:"db-before" => %{:"basis-t" => integer}}) :: integer
  defp basis_t_before(%{:"db-before" => %{:"basis-t" => before_t}}) do
    before_t
  end
  
  @spec basis_t_after(%{:"db-after" => %{:"basis-t" => integer}}) :: integer
  defp basis_t_after(%{:"db-after" => %{:"basis-t" => after_t}}) do
    after_t
  end
  
  @spec tx_data(%{:"tx-data" => [datom_map]}) :: [datom_map]
  defp tx_data(%{:"tx-data" => tx_data}) do
    tx_data
  end
  
  @spec tempids(%{tempids: %{integer => integer}}) :: %{integer => integer}
  defp tempids(%{tempids: tempids}) do
    tempids
  end
end
