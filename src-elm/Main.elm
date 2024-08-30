port module Main exposing (..)

import Browser
import Css
import Html exposing (Html)
import Html.Styled exposing (br, button, div, main_, text, toUnstyled)
import Html.Styled.Attributes exposing (css)
import Html.Styled.Events exposing (onClick)
import Tailwind.Theme exposing (..)
import Tailwind.Utilities exposing (..)



-- MAIN


main : Program () Model Msg
main =
    Browser.element { init = init, update = update, view = view, subscriptions = subscriptions }



-- MODEL


type alias Model =
    { message : String
    }


init : () -> ( Model, Cmd msg )
init _ =
    ( { message = "..." }, Cmd.none )



-- PORT


port updateText : (String -> msg) -> Sub msg


port svn : () -> Cmd msg



-- UPDATE


type Msg
    = UpdateText String
    | Svn


update : Msg -> Model -> ( Model, Cmd msg )
update msg model =
    case msg of
        UpdateText txt ->
            ( { model | message = txt }, Cmd.none )

        Svn ->
            ( model, svn () )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ updateText UpdateText
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
                , w_32
                , py_2
                , Css.hover [ bg_color gray_600 ]
                , Css.active [ bg_color gray_800 ]
                ]
    in
    toUnstyled <|
        main_ []
            [ div []
                [ button [ buttonStyle, onClick Svn ] [ text "svn" ]
                , br [] []
                , div [] [ text model.message ]
                ]
            ]
