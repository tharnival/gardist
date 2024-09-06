port module Main exposing (..)

import Browser
import Css
import Dict exposing (Dict)
import Html exposing (Html)
import Html.Styled exposing (a, br, button, div, input, main_, text, textarea, toUnstyled)
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
    | Removed
    | Unknown


type FsType
    = File
    | Dir Bool


type alias ChangeStatus =
    { checked : Bool
    , changeType : ChangeType
    , fsType : FsType
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


port svn : String -> Cmd msg


port setPath : () -> Cmd msg


port commit :
    { root : String
    , msg : String
    , changes : List ( String, Bool )
    }
    -> Cmd msg


port updatePath : (Maybe String -> msg) -> Sub msg


type alias StatusOutput =
    { info : String
    , path : String
    , isDir : Bool
    }


port updateStatus : (List StatusOutput -> msg) -> Sub msg



-- UPDATE


type Msg
    = UpdateStatus (List StatusOutput)
    | Svn
    | SetPath
    | UpdatePath (Maybe String)
    | HandleCheck String Bool
    | CommitMsg String
    | Commit
    | Expand String Bool


update : Msg -> Model -> ( Model, Cmd msg )
update msg model =
    case msg of
        UpdateStatus status ->
            ( { model | status = parseStatus status }, Cmd.none )

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
                    let
                        changeList =
                            model.status
                                |> Dict.toList
                                |> List.filter (\( _, status ) -> status.changeType /= Unknown)

                        paths =
                            changeList
                                |> List.filter (\( _, status ) -> status.checked)
                                |> List.map fst

                        adds =
                            changeList
                                |> List.map (\( _, status ) -> status.changeType /= Removed)
                    in
                    List.map2 Tuple.pair paths adds
                }
            )

        Expand path expanded ->
            let
                newStatus =
                    model.status
                        |> Dict.update path
                            (Maybe.map
                                (\status ->
                                    { status | fsType = Dir expanded }
                                )
                            )
            in
            ( { model | status = newStatus }, Cmd.none )


parseStatus : List StatusOutput -> Dict String ChangeStatus
parseStatus status =
    status
        |> List.map
            (\change ->
                let
                    changeType =
                        case change.info |> String.toList |> List.head of
                            Just 'M' ->
                                Modified

                            Just 'R' ->
                                Modified

                            Just 'A' ->
                                Added

                            Just '?' ->
                                Added

                            Just 'D' ->
                                Removed

                            Just '!' ->
                                Removed

                            _ ->
                                Unknown

                    fsType =
                        if change.isDir then
                            Dir True

                        else
                            File
                in
                ( change.path
                , { checked = True
                  , changeType = changeType
                  , fsType = fsType
                  }
                )
            )
        |> Dict.fromList



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
                    |> formatChanges
                -- |> List.map
                --     (\( item, status ) ->
                --         [ text
                --             (case status.changeType of
                --                 Added ->
                --                     "+"
                --                 Modified ->
                --                     "~"
                --                 Removed ->
                --                     "-"
                --                 Unknown ->
                --                     "?"
                --             )
                --         , text
                --             (case status.fsType of
                --                 Dir True ->
                --                     "V"
                --                 Dir False ->
                --                     ">"
                --                 File ->
                --                     "_"
                --             )
                --         , input
                --             [ css checkboxStyle
                --             , type_ "checkbox"
                --             , checked status.checked
                --             , onCheck (HandleCheck item)
                --             ]
                --             [ text "test" ]
                --         , text item
                --         , br [] []
                --         ]
                --     )
                -- |> List.concat
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


formatChanges : List ( String, ChangeStatus ) -> List (SHtml Msg)
formatChanges changes =
    -- no relative paths can begin with '/'
    doFormatChanges [] "/" changes
        |> List.reverse
        |> List.concat


expanderStyle : Style
expanderStyle =
    [ w_6
    , h_6
    , text_base
    ]


indentStyle : Style
indentStyle =
    [ py_0
    , px_3
    ]


doFormatChanges : List (List (SHtml Msg)) -> String -> List ( String, ChangeStatus ) -> List (List (SHtml Msg))
doFormatChanges acc hidePrefix changes =
    case changes of
        [] ->
            acc

        ( path, status ) :: tl ->
            if not <| String.startsWith hidePrefix path then
                let
                    changeType =
                        case status.changeType of
                            Added ->
                                "+"

                            Modified ->
                                "~"

                            Removed ->
                                "-"

                            Unknown ->
                                "?"

                    ( expander, newPrefix ) =
                        case status.fsType of
                            File ->
                                ( text "", hidePrefix )

                            Dir False ->
                                ( button
                                    [ css expanderStyle
                                    , onClick (Expand path True)
                                    ]
                                    [ text ">" ]
                                , path
                                )

                            Dir True ->
                                ( button
                                    [ css expanderStyle
                                    , onClick (Expand path False)
                                    ]
                                    [ text "V" ]
                                , hidePrefix
                                )

                    components =
                        String.split "/" path

                    name =
                        components
                            |> List.reverse
                            |> List.head
                            |> Maybe.withDefault ""

                    indentation =
                        List.length components - 1

                    html =
                        List.repeat indentation (a [ css indentStyle ] [])
                            ++ [ expander
                               , input
                                    [ css checkboxStyle
                                    , type_ "checkbox"
                                    , checked status.checked
                                    , onCheck (HandleCheck path)
                                    ]
                                    []
                               , text changeType
                               , text name
                               , br [] []
                               ]
                in
                doFormatChanges (html :: acc) newPrefix tl

            else
                doFormatChanges acc hidePrefix tl
