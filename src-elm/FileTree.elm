module FileTree exposing (FileTree, empty, expand, fromStatus, getCommitPaths, insert, updateCheck, view)

import Dict exposing (Dict)
import Html.Styled as SHtml exposing (a, button, div, input, td, text)
import Html.Styled.Attributes exposing (..)
import Html.Styled.Events exposing (onCheck, onClick)
import Path exposing (Path)
import Ports exposing (StatusOutput)
import Styles
import Tailwind.Utilities exposing (..)
import Types exposing (..)


type FileTree
    = File ChangeStatus
    | Dir ChangeStatus Bool (Dict String FileTree)


type ChangeType
    = Added
    | Modified
    | Removed
    | Root
    | Unknown


type alias ChangeStatus =
    { checked : Bool
    , changeType : ChangeType
    }


empty : FileTree
empty =
    Dir { checked = True, changeType = Root } True Dict.empty


insert : Path -> ChangeStatus -> Bool -> FileTree -> FileTree
insert path status isDir fileTree =
    case fileTree of
        File _ ->
            fileTree

        Dir parentStatus expanded contents ->
            case path of
                [] ->
                    fileTree

                [ component ] ->
                    let
                        insertion =
                            if isDir then
                                Dir status True Dict.empty

                            else
                                File status
                    in
                    Dir parentStatus
                        expanded
                        (Dict.update component
                            (\x -> Just <| Maybe.withDefault insertion x)
                            contents
                        )

                hd :: tl ->
                    let
                        newContents =
                            contents
                                |> Dict.update hd
                                    (\x ->
                                        x
                                            |> Maybe.withDefault
                                                (Dir
                                                    { checked = True, changeType = Added }
                                                    True
                                                    Dict.empty
                                                )
                                            |> insert tl status isDir
                                            |> Just
                                    )
                    in
                    Dir parentStatus expanded newContents


updateCheck : Path -> Bool -> FileTree -> FileTree
updateCheck path checked fileTree =
    case fileTree of
        File status ->
            if List.isEmpty path then
                File { status | checked = checked }

            else
                fileTree

        Dir status expanded contents ->
            case path of
                [] ->
                    let
                        newContents =
                            contents
                                |> Dict.map
                                    (\_ -> recursiveCheck checked)
                    in
                    Dir { status | checked = checked } expanded newContents

                hd :: tl ->
                    contents
                        |> Dict.update hd
                            (Maybe.map (updateCheck tl checked))
                        |> Dir
                            -- any parent directory will have to be checked
                            { status | checked = True }
                            expanded


recursiveCheck : Bool -> FileTree -> FileTree
recursiveCheck checked fileTree =
    case fileTree of
        File status ->
            File { status | checked = checked }

        Dir status expanded contents ->
            let
                newContents =
                    contents
                        |> Dict.map
                            (\_ -> recursiveCheck checked)
            in
            Dir { status | checked = checked } expanded newContents


getCommitPaths : FileTree -> List ( String, Bool )
getCommitPaths fileTree =
    doGetCommitPaths fileTree []
        -- get rid of path to project root
        |> List.tail
        |> Maybe.withDefault []


doGetCommitPaths : FileTree -> Path -> List ( String, Bool )
doGetCommitPaths fileTree path =
    case fileTree of
        File status ->
            if status.checked then
                [ ( Path.toString <| List.reverse path, status.changeType /= Removed ) ]

            else
                []

        Dir status _ contents ->
            if status.checked then
                contents
                    |> Dict.toList
                    |> List.filter
                        (\( _, ft ) ->
                            case ft of
                                File st ->
                                    st.checked

                                Dir st _ _ ->
                                    st.checked
                        )
                    |> List.map
                        (\( p, ft ) ->
                            doGetCommitPaths ft (p :: path)
                        )
                    |> List.concat
                    |> (::) ( Path.toString <| List.reverse path, status.changeType /= Removed )

            else
                []


expand : Path -> Bool -> FileTree -> FileTree
expand path newExpanded fileTree =
    case fileTree of
        File _ ->
            fileTree

        Dir status expanded contents ->
            case path of
                [] ->
                    Dir status newExpanded contents

                hd :: tl ->
                    contents
                        |> Dict.update hd
                            (Maybe.map (expand tl newExpanded))
                        |> Dir status expanded


fromStatus : List StatusOutput -> FileTree
fromStatus =
    List.foldl
        (\e acc ->
            let
                changeType =
                    case e.info |> String.toList |> List.head of
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

                changeStatus =
                    { checked = True
                    , changeType = changeType
                    }
            in
            insert (Path.fromString e.path) changeStatus e.isDir acc
        )
        empty


view : FileTree -> List (SHtml Msg)
view =
    doView Path.empty


doView : Path -> FileTree -> List (SHtml Msg)
doView path fileTree =
    case fileTree of
        File status ->
            a [ css Styles.indent ] []
                :: entry path status

        Dir status expanded contents ->
            let
                inner =
                    if not expanded then
                        []

                    else
                        contents
                            |> Dict.toList
                            |> List.map
                                (\( component, subTree ) ->
                                    let
                                        rec =
                                            doView (component :: path) subTree
                                    in
                                    div [] rec
                                )

                expander =
                    if expanded then
                        button
                            [ css Styles.expander
                            , onClick (Expand (List.reverse path) False)
                            ]
                            [ text "V" ]

                    else
                        button
                            [ css Styles.expander
                            , onClick (Expand (List.reverse path) True)
                            ]
                            [ text ">" ]
            in
            expander
                :: entry path status
                ++ [ SHtml.table []
                        [ td [ css Styles.indent ] []
                        , td [] inner
                        ]
                   ]


entry : Path -> ChangeStatus -> List (SHtml Msg)
entry path status =
    let
        name =
            path
                |> List.head
                |> Maybe.withDefault ""

        changeType =
            case status.changeType of
                Added ->
                    "+"

                Modified ->
                    "~"

                Removed ->
                    "-"

                Root ->
                    ""

                Unknown ->
                    "?"
    in
    [ input
        [ css Styles.checkbox
        , type_ "checkbox"
        , checked status.checked
        , onCheck (HandleCheck <| List.reverse path)
        ]
        []
    , text changeType
    , text name
    ]
