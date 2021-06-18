(** Loading credentials locally or from IAM service. *)
type t = {
  access_key: string;
  secret_key: string;
  token: string option;
  expiration: float option;
}

(** Make credentials *)
val make :
  access_key:string -> secret_key:string ->
  ?token:string -> ?expiration:float -> unit -> t

module Make(Io : Types.Io) : sig
  open Io

  module Iam : sig

    (** Get machine role though IAM service *)
    val get_role : unit -> string Deferred.Or_error.t

    (** Retrieve a credentials for a given role [role] *)
    val get_credentials : string -> t Deferred.Or_error.t

  end

  module Helper : sig

    (** Get credentials locally or though IAM service.
        [profile] is used to speficy a specific section thethe local file.

        If profile is not supplied and no credentials can be found in
        the default section, then credentials are retrieved though Iam
        service, using an assigned machine role.
    *)
    val get_credentials :
      ?profile:string -> unit -> t Deferred.Or_error.t
  end
end
