port module Main exposing (..)

import Browser
import Css
import Dict exposing (Dict)
import Html exposing (Html)
import Html.Styled exposing (br, button, div, input, main_, text, textarea, toUnstyled)
import Html.Styled.Attributes exposing (..)
import Html.Styled.Events exposing (onCheck, onClick, onInput)
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


type ChangeType
    = Added
    | Modified


type alias ChangeStatus =
    { checked : Bool
    , changeType : ChangeType
    }


type alias Model =
    { status : Dict String ChangeStatus
    , path : Maybe String
    , commitMsg : String
    }


init : () -> ( Model, Cmd msg )
init _ =
    ( { status = Dict.empty
      , path = Nothing
      , commitMsg = ""
      }
    , Cmd.none
    )



-- PORT


port updateStatus : (List ( String, String ) -> msg) -> Sub msg


port svn : String -> Cmd msg


port setPath : () -> Cmd msg


port updatePath : (Maybe String -> msg) -> Sub msg


port updateThing : (String -> msg) -> Sub msg


port commit :
    { root : String
    , msg : String
    , changes : List String
    }
    -> Cmd msg



-- UPDATE


type Msg
    = UpdateStatus (List ( String, String ))
    | Svn
    | SetPath
    | UpdatePath (Maybe String)
    | HandleCheck String Bool
    | CommitMsg String
    | Commit


update : Msg -> Model -> ( Model, Cmd msg )
update msg model =
    case msg of
        UpdateStatus status ->
            let
                parsedStatus =
                    status
                        |> List.map
                            (\( tags, path ) ->
                                let
                                    changeType =
                                        if String.startsWith "M" tags then
                                            Modified

                                        else
                                            Added
                                in
                                ( path
                                , { checked = True
                                  , changeType = changeType
                                  }
                                )
                            )
                        |> Dict.fromList
            in
            ( { model | status = parsedStatus }, Cmd.none )

        Svn ->
            ( model, svn <| Maybe.withDefault "." model.path )

        HandleCheck path checked ->
            let
                newStatus =
                    model.status
                        |> Dict.update path (Maybe.map (\x -> { x | checked = checked }))
            in
            if checked then
                ( { model | status = newStatus }, Cmd.none )

            else
                ( { model | status = newStatus }, Cmd.none )

        SetPath ->
            ( model, setPath () )

        UpdatePath path ->
            if isJust path then
                ( { model | path = path }, svn <| Maybe.withDefault "." path )

            else
                -- don't overwrite existing path with nothing
                ( model, Cmd.none )

        CommitMsg commitMsg ->
            ( { model | commitMsg = commitMsg }, Cmd.none )

        Commit ->
            ( { model | commitMsg = "" }
            , commit
                { root = Maybe.withDefault "." model.path
                , msg = model.commitMsg
                , changes =
                    model.status
                        |> Dict.toList
                        |> List.filter (\( _, status ) -> status.checked)
                        |> List.map fst
                }
            )



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
    , Css.disabled [ Css.hover [ bg_color gray_300 ] ]
    ]


checkboxStyle : Style
checkboxStyle =
    [ w_4
    , h_4
    ]


textFieldStyle : Style
textFieldStyle =
    [ h_32
    , rounded_md
    , text_2xl
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
                        (\( item, status ) ->
                            [ text
                                (case status.changeType of
                                    Added ->
                                        "+"

                                    Modified ->
                                        "~"
                                )
                            , input
                                [ css checkboxStyle
                                , type_ "checkbox"
                                , checked status.checked
                                , onCheck (HandleCheck item)
                                ]
                                [ text "test" ]
                            , text item
                            , br [] []
                            ]
                        )
                    |> List.concat
               )
            ++ [ br [] []
               , textarea
                    [ css textFieldStyle
                    , placeholder "Commit message"
                    , value model.commitMsg
                    , onInput CommitMsg
                    ]
                    []
               , br [] []
               , button
                    [ css <| buttonStyle ++ [ w_32 ]
                    , disabled <|
                        -- don't allow commiting if there is no message
                        -- or no changes added
                        (model.commitMsg == "")
                            || (Dict.values model.status
                                    |> List.any (\x -> x.checked)
                                    |> not
                               )
                    , onClick Commit
                    ]
                    [ text "commit" ]
               ]

    else
        []
