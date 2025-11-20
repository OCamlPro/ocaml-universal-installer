module Result : sig
  val (let*) :
    ('a, 'err) result ->
    ('a -> ('b, 'err) result) ->
    ('b, 'err) result

  val (let+) :
    ('a, 'err) result ->
    ('a -> 'b) ->
    ('b, 'err) result
end
