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


type alias SHtml x =
    Html.Styled.Html x


type alias Style =
    List Css.Style



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


buttonStyle : Style
buttonStyle =
    [ bg_color gray_300
    , border_0
    , rounded_md
    , text_2xl
    , py_2
    , Css.hover [ bg_color gray_600 ]
    , Css.active [ bg_color gray_800 ]
    ]


view : Model -> Html Msg
view model =
    toUnstyled <|
        main_ []
            [ div []
                ([ button [ css <| buttonStyle ++ [ w_64 ], onClick SetPath ] [ text "choose folder" ]
                 , div [] [ text <| Maybe.withDefault "No path specified" model.path ]
                 ]
                    ++ statusSection model
                )
            ]


statusSection : Model -> List (SHtml Msg)
statusSection model =
    if isJust model.path then
        [ br [] []
        , button [ css <| buttonStyle ++ [ w_32 ], onClick Svn ] [ text "status" ]
        , br [] []
        , div [] [ text model.message ]
        ]

    else
        []
