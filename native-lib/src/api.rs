

use std::{sync::{Arc, RwLock}, borrow::BorrowMut, str::FromStr};

use anyhow::anyhow;
use flutter_rust_bridge::{RustOpaque, frb};
use phonenumber::country::Id::{self, VE};
pub use rustpush::{APNSState, APNSConnection, IDSAppleUser, Message, IDSUser, IDSError, IMClient, IMessage, RecievedMessage, ConversationData, register};

use serde::{Serialize, Deserialize};
use tokio::runtime::Runtime;
use rustpush::BalloonBody;

#[derive(Serialize, Deserialize, Clone)]
struct SavedState {
    push: APNSState,
    users: Vec<IDSUser>
}

#[derive(PartialEq)]
pub enum RegistrationPhase {
    NOT_STARTED,
    WANTS_USER_PASS,
    WANTS_VALID_ID,
    REGISTERED
}

pub struct InnerPushState {
    conn: Option<Arc<APNSConnection>>,
    users: Vec<IDSUser>,
    client: Option<IMClient>
}

pub struct PushState (RwLock<InnerPushState>, RwLock<Runtime>);

pub fn newPushState() -> RustOpaque<PushState> {
    RustOpaque::new(PushState(RwLock::new(InnerPushState {
        conn: None,
        users: vec![],
        client: None
    }), RwLock::new(Runtime::new().unwrap())))
}

pub fn format_e164(number: String, country: String) -> String {
    let id = Id::from_str(&country).unwrap();
    let number = phonenumber::parse(Some(id), number).unwrap();
    let formatter = number.format();
    formatter.mode(phonenumber::Mode::E164);
    format!("{}", formatter)
}

#[frb]
#[repr(C)]
pub struct DartBalloonBody {
    #[frb(non_final)]
    pub bid: String,
    #[frb(non_final)]
    pub data: Vec<u8>
}

#[frb]
#[repr(C)]
pub struct DartConversationData {
    #[frb(non_final)]
    pub participants: Vec<String>,
    #[frb(non_final)]
    pub cv_name: Option<String>,
    #[frb(non_final)]
    pub sender_guid: Option<String>,
}

#[frb]
#[repr(C)]
pub struct DartNormalMessage {
    #[frb(non_final)]
    pub text: String,
    #[frb(non_final)]
    pub xml: Option<String>,
    #[frb(non_final)]
    pub body: Option<DartBalloonBody>,
    #[frb(non_final)]
    pub effect: Option<String>,
    #[frb(non_final)]
    pub reply_guid: Option<String>,
    #[frb(non_final)]
    pub reply_part: Option<String>
}

#[repr(C)]
pub struct DartRenameMessage {
    pub new_name: String
}

#[repr(C)]
pub struct DartChangeParticipantMessage {
    pub new_participants: Vec<String>
}

#[repr(C)]
pub enum DartReaction {
    Heart,
    Like,
    Dislike,
    Laugh,
    Emphsize,
    Question
}

#[repr(C)]
pub struct DartReactMessage {
    pub to_uuid: String,
    pub to_part: u64,
    pub enable: bool,
    pub reaction: DartReaction,
    pub to_text: String,
}

#[repr(C)]
pub struct DartUnsendMessage {
    pub tuuid: String,
    pub edit_part: u64,
}

#[repr(C)]
pub struct DartEditMessage {
    pub tuuid: String,
    pub edit_part: u64,
    pub new_data: String
}

#[repr(C)]
pub enum DartMessage {
    Message(DartNormalMessage),
    RenameMessage(DartRenameMessage),
    ChangeParticipants(DartChangeParticipantMessage),
    React(DartReactMessage),
    Delivered,
    Read,
    Typing,
    Unsend(DartUnsendMessage),
    Edit(DartEditMessage),
}

#[frb]
#[repr(C)]
pub struct DartIMessage {
    #[frb(non_final)]
    pub id: String,
    #[frb(non_final)]
    pub sender: Option<String>,
    #[frb(non_final)]
    pub after_guid: Option<String>,
    #[frb(non_final)]
    pub conversation: Option<DartConversationData>,
    #[frb(non_final)]
    pub message: DartMessage,
    #[frb(non_final)]
    pub sent_timestamp: u64
}

impl Into<Message> for DartMessage {
    fn into(self) -> Message {
        unsafe { std::mem::transmute(self) }
    }
}

impl Into<ConversationData> for DartConversationData {
    fn into(self) -> ConversationData {
        unsafe { std::mem::transmute(self) }
    }
}

impl From<IMessage> for DartIMessage {
    fn from(value: IMessage) -> Self {
        unsafe { std::mem::transmute(value) }
    }
}

impl DartIMessage {
    fn to_imsg(self) -> IMessage {
        unsafe { std::mem::transmute(self) }
    }
}

#[repr(C)]
pub enum DartRecievedMessage {
    Message {
        msg: DartIMessage
    }
}

pub fn recv_wait(state: RustOpaque<PushState>) -> Option<DartRecievedMessage> {
    state.1.read().unwrap().block_on(async {
        if state.get_phase() != RegistrationPhase::REGISTERED {
            panic!("Wrong phase! (recv_wait)")
        }
        state.0.read().unwrap().client.as_ref().unwrap().recieve_wait().await.map(|msg| {
            unsafe { std::mem::transmute(msg) }
        })
    })
}

pub fn send(state: RustOpaque<PushState>, msg: DartIMessage) -> anyhow::Result<()> {
    state.1.read().unwrap().block_on(async {
        if state.get_phase() != RegistrationPhase::REGISTERED {
            panic!("Wrong phase! (send)")
        }
        let mut msg = msg.to_imsg();
        state.0.read().unwrap().client.as_ref().unwrap().send(&mut msg).await?;
        Ok(())
    })
}

pub fn get_handles(state: RustOpaque<PushState>) -> anyhow::Result<Vec<String>> {
    if state.get_phase() != RegistrationPhase::REGISTERED {
        panic!("Wrong phase! (send)")
    }
    Ok(state.0.read().unwrap().client.as_ref().unwrap().get_handles().to_vec())
}

pub fn new_msg(state: RustOpaque<PushState>, conversation: DartConversationData, message: DartMessage) -> DartIMessage {
    state.1.read().unwrap().block_on(async {
        if state.get_phase() != RegistrationPhase::REGISTERED {
            panic!("Wrong phase! (new_msg)")
        }
        let read = state.0.read().unwrap();
        let client = read.client.as_ref().unwrap();
        client.new_msg(conversation.into(), message.into()).await.into()
    })
}

pub fn validate_targets(state: RustOpaque<PushState>, targets: Vec<String>) -> anyhow::Result<Vec<String>> {
    state.1.read().unwrap().block_on(async {
        if state.get_phase() != RegistrationPhase::REGISTERED {
            panic!("Wrong phase! (validate_targets)")
        }
        Ok(state.0.read().unwrap().client.as_ref().unwrap().validate_targets(&targets).await?)
    })
}
pub fn cancel_registration(state: RustOpaque<PushState>) {
    if state.get_phase() != RegistrationPhase::WANTS_VALID_ID {
        return
    }
    let mut inner = state.0.write().unwrap();
    inner.users.clear();
}

pub fn get_phase(state: RustOpaque<PushState>) -> RegistrationPhase {
    state.get_phase()
}

pub fn restore(curr_state: RustOpaque<PushState>, data: String) {
    curr_state.1.read().unwrap().block_on(async {
        if curr_state.get_phase() != RegistrationPhase::NOT_STARTED {
            panic!("Wrong phase! (restore)")
        }
    
        let state: SavedState = serde_json::from_str(&data).unwrap();
    
        let connection = Arc::new(APNSConnection::new(Some(state.push.clone())).await.unwrap());
        connection.submitter.set_state(1).await;
        connection.submitter.filter(&["com.apple.madrid"]).await;
        let mut inner = curr_state.0.write().unwrap();
        inner.conn = Some(connection);
    
        let user = Arc::new(state.users);
    
        inner.client = Some(IMClient::new(inner.conn.as_ref().unwrap().clone(), user.clone()).await);
    })
}

pub fn new_push(state: RustOpaque<PushState>) {
    state.1.read().unwrap().block_on(async {
        if state.get_phase() != RegistrationPhase::NOT_STARTED {
            panic!("Wrong phase! (new_push)")
        }
        let mut inner = state.0.write().unwrap();
        let connection = Arc::new(APNSConnection::new(None).await.unwrap());
        connection.submitter.set_state(1).await;
        connection.submitter.filter(&["com.apple.madrid"]).await;
        inner.conn = Some(connection);
    })
}

pub fn try_auth(state: RustOpaque<PushState>, username: String, password: String) -> anyhow::Result<u64> {
    state.1.read().unwrap().block_on(async {
        if state.get_phase() != RegistrationPhase::WANTS_USER_PASS {
            panic!("Wrong phase! (try_auth)")
        }
        let mut inner = state.0.write().unwrap();
        let identity = match IDSAppleUser::authenticate(inner.conn.as_ref().unwrap().clone(), username.trim(), password.trim()).await {
            Ok(user) => user,
            Err(err) => {
                match err {
                    IDSError::TwoFaError =>
                        return Ok(1),
                    IDSError::AuthError(_) =>
                        return Ok(2),
                    _err => {
                        return Err(anyhow!(_err))
                    }
                }
            }
        };
        inner.users.push(identity);
        
        Ok(0)
    })
}

pub fn register_ids(state: RustOpaque<PushState>, validation_data: String) -> anyhow::Result<u64> {
    state.1.read().unwrap().block_on(async {
        if state.get_phase() != RegistrationPhase::WANTS_VALID_ID {
            panic!("Wrong phase! (register_ids)")
        }
        let mut inner = state.0.write().unwrap();
        let conn_state = inner.conn.as_ref().unwrap().clone();
        if let Err(err) = register(&validation_data, &mut inner.users, conn_state).await {
            return if let IDSError::RegisterFailed(err) = err {
                Ok(err)
            } else {
                Err(anyhow!(err))
            }
        }
        let mut empty_users = vec![];
        std::mem::swap(&mut empty_users, &mut inner.users);
        inner.client = Some(IMClient::new(inner.conn.as_ref().unwrap().clone(), Arc::new(empty_users)).await);
        Ok(0)
    })
}

pub fn save_push(state: RustOpaque<PushState>) -> String {
    if state.get_phase() != RegistrationPhase::REGISTERED {
        panic!("Wrong phase! (save_push)")
    }
    let inner = state.0.read().unwrap();
    let state = SavedState {
        push: inner.conn.as_ref().unwrap().state.clone(),
        users: (*inner.client.as_ref().unwrap().users).clone()
    };
    serde_json::to_string(&state).unwrap()
}

impl PushState {
    fn get_phase(&self) -> RegistrationPhase {
        let inner = self.0.read().unwrap();
        if inner.conn.is_none() {
            return RegistrationPhase::NOT_STARTED
        }
        if inner.users.len() == 0 && inner.client.is_none() {
            return RegistrationPhase::WANTS_USER_PASS
        }
        if inner.client.is_none() {
            return RegistrationPhase::WANTS_VALID_ID
        }
        RegistrationPhase::REGISTERED
    }
}