module Util exposing (..)


isJust : Maybe a -> Bool
isJust x =
    case x of
        Just _ ->
            True

        Nothing ->
            False


fst : ( a, b ) -> a
fst ( x, _ ) =
    x


snd : ( b, a ) -> a
snd ( _, x ) =
    x
