{-# LANGUAGE ExtendedDefaultRules #-}
{-# LANGUAGE OverloadedStrings    #-}
{-# LANGUAGE QuasiQuotes          #-}
{-# LANGUAGE RecursiveDo          #-}
{-# LANGUAGE ScopedTypeVariables  #-}
{-# LANGUAGE TemplateHaskell      #-}

-- |
-- Copyright   :  (C) 2018 Kadena
-- License     :  BSD-style (see the file LICENSE)
--

module Main where

------------------------------------------------------------------------------
import           Control.Lens
import           Control.Monad.State.Strict
import qualified Data.List.Zipper as Z
import           Data.Map (Map)
import qualified Data.Map as M
import           Data.Maybe
import           Data.Monoid
import           Data.Sequence (Seq)
import qualified Data.Sequence as S
import           Data.String.QQ
import           Data.Text (Text)
import qualified Data.Text as T
import           Language.Javascript.JSaddle
import           Reflex
import           Reflex.Dom hiding (Element, fromJSString)
import           Reflex.Dom.ACE
------------------------------------------------------------------------------
import           Pact.Repl
import           Pact.Repl.Types
import           Pact.Types.Lang
------------------------------------------------------------------------------

main :: IO ()
main = mainWidget app

data ControlOut t = ControlOut
    { controlDropdown  :: Dynamic t Text
    , controlLoadEvent :: Event t ()
    }

codeFromResponse :: XhrResponse -> Text
codeFromResponse =
    fromMaybe "error: could not connect to server" . _xhrResponse_responseText

data ClickState = DownAt (Int, Int) | Clicked | Selected
  deriving (Eq,Ord,Show,Read)

app :: MonadWidget t m => m ()
app = do
    ControlOut d le <- controlBar
    elAttr "div" ("id" =: "editor_view") $ mdo
      ex <- performRequestAsync ((\u -> xhrRequest "GET" u def) <$> updated d)
      code <- elAttr "div" ("id" =: "column1") $ do
        codeWidget startingExpression $ codeFromResponse <$> ex
      elAttr "div" ("id" =: "separator" <> "class" =: "separator") blank
      (e,newExpr) <- elAttr' "div" ("id" =: "column2") $ do
        elAttr "div" ("id" =: "code") $ do
          mapM_ snippetWidget staticReplHeader
          clickType <- foldDyn ($) Nothing $ leftmost
            [ setDown <$> domEvent Mousedown e
            , clickClassifier <$> domEvent Mouseup e
            ]
          let replClick = () <$ ffilter (== Just Clicked) (updated clickType)
          widgetHold (replWidget replClick startingExpression) (replWidget replClick <$> tag (current code) le)
      timeToScroll <- delay 0.1 $ switch $ current newExpr
      _ <- performEvent (scrollToBottom (_element_raw e) <$ timeToScroll)
      return ()

setDown :: (Int, Int) -> t -> Maybe ClickState
setDown clickLoc _ = Just $ DownAt clickLoc

clickClassifier :: (Int, Int) -> Maybe ClickState -> Maybe ClickState
clickClassifier clickLoc (Just (DownAt loc1)) =
  if clickLoc == loc1 then Just Clicked else Just Selected
clickClassifier _ _ = Nothing

scrollToBottom :: (PToJSVal t, MonadIO m, MonadJSM m) => t -> m ()
scrollToBottom e = liftJSM $ do
    let pElem = pToJSVal e
    (pElem <# ("scrollTop" :: String)) (pElem ^. js ("scrollHeight" :: String))

codeWidget :: MonadWidget t m => Text -> Event t Text -> m (Dynamic t Text)
codeWidget iv sv = do
    let ac = def { _aceConfigMode = Just "ace/mode/pact"
                 , _aceConfigElemAttrs = "id" =: "ace-widget"
                 }
    ace <- aceWidgetStatic ac (AceDynConfig $ Just AceTheme_SolarizedLight) iv
    _ <- withAceInstance ace (setValueACE <$> sv)
    return $ aceValue ace


data DisplayedSnippet
  = InputSnippet Text
  | OutputSnippet Text
  deriving (Eq,Ord,Show,Read)

staticReplHeader :: Seq DisplayedSnippet
staticReplHeader = S.fromList
      [ OutputSnippet ";; Welcome to the Pact interactive repl"
      , OutputSnippet ";; Use LOAD button to execute editor text"
      , OutputSnippet ";; then just type at the \"seal>\" prompt to interact!"
      ]

snippetWidget :: MonadWidget t m => DisplayedSnippet -> m ()
snippetWidget (InputSnippet t) = elAttr "pre" ("class" =: "replOut") $ text t
snippetWidget (OutputSnippet t) = elAttr "pre" ("class" =: "replOut") $ text t

------------------------------------------------------------------------------
replWidget
    :: MonadWidget t m
    => Event t ()
    -> Text
    -> m (Event t Text)
replWidget replClick initialCode = mdo
    initState <- liftIO $ initReplState StringEval
    stateAndOut0 <- runReplStep0 (initState, mempty) initialCode
    stateAndOut <- holdDyn stateAndOut0 evalResult

    _ <- dyn (mapM_ snippetWidget . snd <$> stateAndOut)
    newInput <- replInput replClick
    evalResult <- performEvent $
      attachWith runReplStep (current stateAndOut) newInput
    return newInput

replInput :: MonadWidget t m => Event t () -> m (Event t Text)
replInput setFocus = do
    divClass "repl-input-controls" $ mdo
      el "span" $ text "seal>"
      let sv = leftmost
            [ mempty <$ enterPressed
            , fromMaybe "" . Z.safeCursor <$> tagPromptlyDyn commandHistory key
            ]
      ti <- textInput (def & setValue .~ sv)
      let key = ffilter isMovement $ domEvent Keydown ti
      let enterPressed = keypress Enter ti
      _ <- performEvent (liftJSM (pToJSVal (_textInput_element ti) ^. js0 ("focus" :: String)) <$ setFocus)
      let newCommand = tag (current $ value ti) enterPressed
      commandHistory <- foldDyn ($) Z.empty $ leftmost
        [ addToHistory <$> newCommand
        , moveHistory <$> key
        ]
      return newCommand

addToHistory :: Eq a => a -> Z.Zipper a -> Z.Zipper a
addToHistory a z =
    if Just a == Z.safeCursor (Z.left zEnd) then zEnd else Z.push a zEnd
  where
    zEnd = Z.end z

isMovement :: (Num a, Eq a) => a -> Bool
isMovement 38 = True
isMovement 40 = True
isMovement _ = False

moveHistory :: (Num a1, Eq a1) => a1 -> Z.Zipper a -> Z.Zipper a
moveHistory 38 = Z.left
moveHistory 40 = Z.right
moveHistory _ = id

runReplStep0
    :: MonadIO m
    => (ReplState, Seq DisplayedSnippet)
    -> Text
    -> m (ReplState, Seq DisplayedSnippet)
runReplStep0 (s1,snippets1) e = do
    (r,s2) <- liftIO $ runStateT (evalRepl' $ T.unpack e) s1
    return (s2, snippets1 <> S.singleton
      (OutputSnippet $ T.pack $ either id (const $ _rOut s2) r))

runReplStep
    :: MonadIO m
    => (ReplState, Seq DisplayedSnippet)
    -> Text
    -> m (ReplState, Seq DisplayedSnippet)
runReplStep (s1,snippets1) e = do
    (eterm,s2) <- liftIO $ runStateT (evalRepl' $ T.unpack e) s1
    return (s2, snippets1 <> S.fromList [InputSnippet ("seal> " <> e), OutputSnippet $ showResult eterm])

showResult :: Show a => Either String a -> Text
showResult (Right v) = T.pack $ show v
showResult (Left e) = "Error: " <> T.pack e

controlBar :: MonadWidget t m => m (ControlOut t)
controlBar = do
    elAttr "div" ("id" =: "options") $ do
      elAttr "div" ("style" =: "display: block;") $ do
        o <- elAttr "ul" ("class" =: "view_mode") $ do
          elAttr "li" ("id" =: "pactVersion") $
            elAttr "a" ("target" =: "_blank" <> "href" =: "https://github.com/kadena-io/pact") $ do
              is <- liftIO $ initReplState StringEval
              Right (TLiteral (LString ver) _) <- liftIO $ evalStateT (evalRepl' "(seal-version)") is
              text $ "Pact Version " <> ver
          d <- elAttr "li" ("class" =: "code_examples_fieldset") $ do
            elAttr "fieldset" ("class" =: "code_examples_fieldset") $ do
                dropdown 0 (constDyn $ fmap fst demos) def
          load <- elAttr "li" ("id" =: "loadButton" <> "class" =: "tooltip") $ do
            (e,_) <- elAttr' "label" ("id" =: "compile_now") $ text "Load"
            return $ domEvent Click e

          let intToCode n = snd $ fromJust $ M.lookup n demos
          return (ControlOut (intToCode <$> value d) load)
        elAttr "ul" ("class" =: "view_mode" <> "style" =: "float: right") $ do
          el "li" $
            el "label" $
              elAttr "a" ("target" =: "_blank" <>
                          "style" =: "color:black;text-decoration:none;" <>
                          "href" =: "http://pact-language.readthedocs.io"
                          ) $ do
                elAttr "i" ("class" =: "fa fa-book" <> "aria-hidden" =: "true") blank
                elAttr "span" ("id" =: "hideIfTiny" <> "class" =: "menu-link") $ text "Docs"
          el "li" $
            elAttr "a" ("target" =: "_blank" <> "href" =: "http://kadena.io") $
              elAttr "img" ("src" =: "img/kadena-logo84x20.png" <> "class" =: "logo-image") blank
        return o

exampleData :: [(Text, Text)]
exampleData =
  [ ("Hello World", "examples/helloWorld-1.0.repl")
  , ("Simple Payment", "examples/simplePayments-1.0.repl")
  , ("International Payment", "examples/internationalPayments-1.0.repl")
  , ("Commercial Paper", "examples/commercialPaper-1.0.repl")
  ]

demos :: Map Int (Text, Text)
demos = M.fromList $ zip [0..] exampleData

------------------------------------------------------------------------------
-- | We still have this hard coded initial value because Reflex has to put
-- some value in before the first event fires, so we use this one.  It should
-- match the first element of the exampleData list.
startingExpression :: Text
startingExpression = [s|
;;
;; "Hello, world!" smart contract/module
;;

;; Simulate message data specifying an administrator keyset.
;; In production use 'mockAdminKey' would be an ED25519 hex-encoded public key.
(env-data { "admin-keyset": ["mockAdminKey"] })

;; Simulate that we've signed this transaction with the keyset.
;; In pact, signatures are pre-validated and represented in the
;; environment as a list of public keys.
(env-keys ["mockAdminKey"])

;; Keysets cannot be created in code, thus we read them in
;; from the load message data.
(define-keyset 'admin-keyset (read-keyset "admin-keyset"))

;; Define the module.
(module helloWorld 'admin-keyset
  "A smart contract to greet the world."
  (defun hello (name)
    "Do the hello-world dance"
    (format "Hello {}!" [name]))
)

;; and say hello!
(hello "world")
|]
