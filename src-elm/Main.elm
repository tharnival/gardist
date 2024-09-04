port module Main exposing (..)

import Browser
import Css
import Dict exposing (Dict)
import Html exposing (Html)
import Html.Styled exposing (br, button, div, input, main_, text, toUnstyled)
import Html.Styled.Attributes exposing (..)
import Html.Styled.Events exposing (onCheck, onClick)
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
    { status : Dict String Bool
    , path : Maybe String
    }


init : () -> ( Model, Cmd msg )
init _ =
    ( { status = Dict.empty, path = Nothing }, Cmd.none )



-- PORT


type alias Change =
    { root : String
    , path : String
    }


port updateStatus : (List ( String, String ) -> msg) -> Sub msg


port svn : String -> Cmd msg


port svnAdd : Change -> Cmd msg


port svnRemove : Change -> Cmd msg


port setPath : () -> Cmd msg


port updatePath : (Maybe String -> msg) -> Sub msg


port updateThing : (String -> msg) -> Sub msg



-- UPDATE


type Msg
    = UpdateStatus (List ( String, String ))
    | Svn
    | SetPath
    | UpdatePath (Maybe String)
    | HandleCheck String Bool


update : Msg -> Model -> ( Model, Cmd msg )
update msg model =
    case msg of
        UpdateStatus status ->
            let
                parsedStatus =
                    status
                        |> List.map
                            (\( tags, path ) ->
                                if String.startsWith "A" tags then
                                    ( path, True )

                                else
                                    ( path, False )
                            )
                        |> Dict.fromList
            in
            ( { model | status = parsedStatus }, Cmd.none )

        Svn ->
            ( model, svn <| Maybe.withDefault "." model.path )

        HandleCheck path checked ->
            let
                newStatus =
                    Dict.insert path checked model.status
            in
            if checked then
                ( { model | status = newStatus }
                , svnAdd
                    { root = Maybe.withDefault "." model.path
                    , path = path
                    }
                )

            else
                ( { model | status = newStatus }
                , svnRemove
                    { root = Maybe.withDefault "." model.path
                    , path = path
                    }
                )

        SetPath ->
            ( model, setPath () )

        UpdatePath path ->
            if isJust path then
                ( { model | path = path }, svn <| Maybe.withDefault "." path )

            else
                -- don't overwrite existing path with nothing
                ( model, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ updateStatus UpdateStatus
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


checkboxStyle : Style
checkboxStyle =
    [ w_4
    , h_4
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
        , button [ css <| buttonStyle ++ [ w_64 ], onClick Svn ] [ text "update status" ]
        , br [] []
        ]
            ++ (model.status
                    |> Dict.toList
                    |> List.map
                        (\( item, added ) ->
                            [ input
                                [ css checkboxStyle
                                , type_ "checkbox"
                                , checked added
                                , onCheck (HandleCheck item)
                                ]
                                [ text "test" ]
                            , text item
                            , br [] []
                            ]
                        )
                    |> List.concat
               )

    else
        []
