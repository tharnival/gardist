port module Main exposing (..)

import Browser
import Css
import Html exposing (Html)
import Html.Styled exposing (br, button, div, main_, text, toUnstyled)
import Html.Styled.Attributes exposing (..)
import Html.Styled.Events exposing (onClick)
import Tailwind.Theme exposing (..)
import Tailwind.Utilities exposing (..)
import Util exposing (..)



-- MAIN


main : Program () Model Msg
main =
    Browser.element { init = init, update = update, view = view, subscriptions = subscriptions }



-- MODEL


type alias Model =
    { message : String
    , path : Maybe String
    }


init : () -> ( Model, Cmd msg )
init _ =
    ( { message = "...", path = Nothing }, Cmd.none )



-- PORT


port updateText : (String -> msg) -> Sub msg


port svn : String -> Cmd msg


port setPath : () -> Cmd msg


port updatePath : (Maybe String -> msg) -> Sub msg



-- UPDATE


type Msg
    = UpdateText String
    | Svn
    | SetPath
    | UpdatePath (Maybe String)


update : Msg -> Model -> ( Model, Cmd msg )
update msg model =
    case msg of
        UpdateText txt ->
            ( { model | message = txt }, Cmd.none )

        Svn ->
            ( model, svn <| Maybe.withDefault "." model.path )

        SetPath ->
            ( model, setPath () )

        UpdatePath path ->
            ( { model
                | path =
                    -- don't overwrite existing path with nothing
                    if isJust path then
                        path

                    else
                        model.path
              }
            , Cmd.none
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ updateText UpdateText
        , updatePath UpdatePath
        ]



-- VIEW


view : Model -> Html Msg
view model =
    let
        buttonStyle =
            css
                [ bg_color gray_300
                , border_0
                , rounded_md
                , text_2xl
                , w_64
                , py_2
                , Css.hover [ bg_color gray_600 ]
                , Css.active [ bg_color gray_800 ]
                ]
    in
    toUnstyled <|
        main_ []
            [ div []
                [ button [ buttonStyle, onClick SetPath ] [ text "choose folder" ]
                , div [] [ text <| Maybe.withDefault "No path specified" model.path ]
                , br [] []
                , button [ buttonStyle, onClick Svn ] [ text "status" ]
                , br [] []
                , div [] [ text model.message ]
                ]
            ]
