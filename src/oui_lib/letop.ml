module Result = struct
  let (let*) = Result.bind
  let (let+) o f = Result.map f o
end
