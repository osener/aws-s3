type vendor

type t =
  | Ap_northeast_1
  | Ap_northeast_2
  | Ap_northeast_3
  | Ap_southeast_1
  | Ap_southeast_2
  | Ap_south_1
  | Eu_central_1
  | Cn_northwest_1
  | Cn_north_1
  | Eu_west_1
  | Eu_west_2
  | Eu_west_3
  | Sa_east_1
  | Us_east_1
  | Us_east_2
  | Us_west_1
  | Us_west_2
  | Ca_central_1
  | Other of string
  | Vendor of vendor

val vendor : region_name:string -> ?port:int -> host:string -> unit -> t

val minio : ?port:int -> host:string -> unit -> t

val backblaze : region_name:string -> unit -> t

type endpoint = {
  inet: [`V4 | `V6];
  scheme: [`Http | `Https];
  host: string;
  port: int;
  region: t;
}

val endpoint :
  inet:[`V4 | `V6] -> scheme:[`Http | `Https] -> t -> endpoint

val to_string : t -> string
val of_string : string -> t
val of_host : string -> t
