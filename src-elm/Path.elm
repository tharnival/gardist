module Path exposing (..)


type alias Path =
    List String


empty : Path
empty =
    []


fromString : String -> Path
fromString str =
    String.replace "\\" "/" str
        |> String.split "/"


toString : Path -> String
toString =
    -- Windows command line also accepts '/' for paths
    String.join "/"
