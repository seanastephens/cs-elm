module App exposing (main)

import Dict exposing (Dict)
import Html exposing (div, text)
import Html.App
import Task exposing (Task)
import LoggedIn.Messages as LIMsg
import LoggedIn.Model as LIModel
import LoggedIn.Update as LIUpdate
import LoggedIn.View as LIView
import LoggedOut.Messages as LOMsg
import LoggedOut.Model as LOModel
import LoggedOut.Update as LOUpdate
import LoggedOut.View as LOView
import Models.Conversation exposing (Conversation)
import Models.User exposing (User)
import Tasks.AuthenticateUser exposing (LoginInfo)
import Tasks.FetchConversations exposing (fetchConversations)
import Tasks.FetchMe exposing (fetchMe)


type Msg
    = LoggedOutMsg LOMsg.Msg
    | LoggedInMsg LIMsg.Msg
    | FetchConversations (Result String ( Dict Int Conversation, Dict Int User ))
    | FetchMeFailed String
    | FetchMeLoaded (Result String User)


type AuthenticationStatus
    = LoggedOut
    | LoggedIn LoginInfo


type alias Model =
    { authStatus : AuthenticationStatus
    , loggedOut : LOModel.Model
    , loggedIn : LIModel.Model
    }


initialModel : Model
initialModel =
    { authStatus = LoggedOut
    , loggedOut = LOModel.emptyModel
    , loggedIn = LIModel.emptyModel
    }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        FetchConversations response ->
            case response of
                Ok ( conversations, users ) ->
                    ( { model
                        | loggedIn = LIUpdate.mergeConversations model.loggedIn conversations users
                      }
                    , Cmd.none
                    )

                Err _ ->
                    ( model, Cmd.none )

        FetchMeFailed error ->
            ( model, Cmd.none )

        FetchMeLoaded result ->
            case result of
                Ok me ->
                    ( { model
                        | loggedIn = LIUpdate.setMe model.loggedIn me
                      }
                    , Cmd.none
                    )

                Err error ->
                    ( model, Cmd.none )

        LoggedOutMsg subMsg ->
            let
                ( loggedOut, cmd, info ) =
                    LOUpdate.update subMsg model.loggedOut
            in
                let
                    authStatus =
                        case info of
                            Just loginInfo ->
                                LoggedIn loginInfo

                            Nothing ->
                                LoggedOut

                    ( fetchMyUser, fetchConversationList ) =
                        case info of
                            Just loginInfo ->
                                ( fetchMe loginInfo
                                    |> Task.perform FetchMeFailed FetchMeLoaded
                                , fetchConversations loginInfo
                                    |> Task.perform FetchConversations FetchConversations
                                )

                            Nothing ->
                                ( Cmd.none, Cmd.none )
                in
                    ( { model
                        | loggedOut = loggedOut
                        , authStatus = authStatus
                      }
                    , Cmd.batch
                        [ Cmd.map LoggedOutMsg cmd
                        , fetchMyUser
                        , fetchConversationList
                        ]
                    )

        LoggedInMsg subMsg ->
            case subMsg of
                LIMsg.Logout ->
                    ( { model
                        | authStatus = LoggedOut
                        , loggedOut = LOModel.emptyModel
                      }
                    , Cmd.none
                    )

                _ ->
                    let
                        loginInfo =
                            case model.authStatus of
                                LoggedIn info ->
                                    info

                                LoggedOut ->
                                    { apiKey = "", email = "" }

                        ( loggedIn, cmd ) =
                            LIUpdate.update subMsg model.loggedIn loginInfo
                    in
                        ( { model | loggedIn = loggedIn }, Cmd.map LoggedInMsg cmd )


view : Model -> Html.Html Msg
view model =
    case model.authStatus of
        LoggedIn info ->
            Html.App.map LoggedInMsg (LIView.view model.loggedIn info)

        LoggedOut ->
            Html.App.map LoggedOutMsg (LOView.view model.loggedOut)


main : Program Never
main =
    Html.App.program
        { init = ( initialModel, Cmd.none )
        , view = view
        , update = update
        , subscriptions = always Sub.none
        }
