module Styles exposing (..)

import Css
import Tailwind.Theme exposing (..)
import Tailwind.Utilities exposing (..)


type alias Style =
    List Css.Style


button : Style
button =
    [ bg_color gray_300
    , border_0
    , rounded_md
    , text_2xl
    , py_2
    , Css.hover [ bg_color gray_600 ]
    , Css.active [ bg_color gray_800 ]
    , Css.disabled [ Css.hover [ bg_color gray_300 ] ]
    ]


tab : Style
tab =
    button
        ++ [ w_32
           , mt_3
           , mr_3
           , Css.disabled
                [ bg_color blue_400
                , Css.hover [ bg_color blue_400 ]
                ]
           ]


text : Style
text =
    [ rounded_md
    , text_2xl
    , m_2
    ]


textField : Style
textField =
    [ h_32
    , rounded_md
    , text_2xl
    ]


checkbox : Style
checkbox =
    [ w_4
    , h_4
    ]


expander : Style
expander =
    [ w_6
    , h_6
    , text_base
    ]


indent : Style
indent =
    [ py_0
    , px_3
    ]


logEntry : Style
logEntry =
    [ bg_color gray_300
    , relative
    , rounded_md
    , w_96
    , my_2
    , p_2
    ]
