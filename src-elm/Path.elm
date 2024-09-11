module Path exposing (..)


type alias Path =
    List String


empty : Path
empty =
    []


fromString : String -> Path
fromString =
    String.split "/"


toString : Path -> String
toString =
    String.join "/"
