(* Thin stdlib compat layer until stdcompat catches up with the latest compiler.
*)

module List = struct
  include Stdlib.List

  let find_mapi f =
    let rec aux i = function
      | [] -> None
      | x :: l ->
        begin match f i x with
          | Some _ as result -> result
          | None -> aux (i+1) l
        end in
    aux 0
end
