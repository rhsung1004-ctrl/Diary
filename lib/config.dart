/// Google Cloud 콘솔에서 만든 "웹 애플리케이션" OAuth 클라이언트 ID.
/// (안드로이드 구글 로그인에 serverClientId 로 필요. 비밀값이 아니라 코드에 넣어도 됨)
const kGoogleServerClientId = '557221105650-5o5keg7ovhd95r70e6cp9m4bd8ui5dv4.apps.googleusercontent.com';

/// 프로(평생 이용권) 인앱 상품 ID — 플레이 콘솔에서 같은 ID로 "일회성 상품"을 만들어야 함
const kProProductId = 'lifebox_pro';

/// 프로 잠금 스위치. 플레이 콘솔에 상품을 만들고 결제 테스트가 끝나면 true 로 바꿈.
/// false 인 동안에는 모든 기능이 열려 있음.
const kProGateEnabled = false;
