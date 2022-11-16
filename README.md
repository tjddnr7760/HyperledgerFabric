# 하이퍼레저 패브릭 구현 과제
## 버전 정리

hyperledgder fabric - 2.2

hyperledgger fabric ca -  1.4.7

docker - 20.10.21

docker-compose - 1.27.4

node - 12.22.12

git  - 2.25.1

curl - 7.68.0

#
## 컨소시엄 구조
- 조직 2개
- 조직당 CA 1개
- 조직당 피어 2개
- 오더러 3개
- 채널 1개
- 체인코드
- PDC
- DApp

#
## 네트워크 구축 과정
1. CA 기본 구축(MSP) -> Orderer CA, Org1 CA1, Org2 CA2
2. 오더링 서비스 3개 구축
3. configuration block 설정
4. 채널 생성
5. 피어 채널 참석
6. 체인코드 배포
7. DApp 연결

#
## 세부 구현 과정
### 네트워크 구축과정 1번 ~ 3번
1. docker-compose-ca.yaml파일 -> 조직3개에 대한 ca생성
2. registerEnroll.sh파일 조직당 identity 생성함수 수정
3. ccp-generate.sh파일 연결 설정
4. docker-compose-test-net-yaml 파일 조건에 맞게 수정
5. docker-compose-couch.yaml 파일 조건에 맞게 수정
6. config.tx파일 (configtxgen명령어 관련) 추가한 값에 맞게 수정 -> (오더러 genesis 블록 재설정, 추가된 피어, 추가된 오더러 등)

### 채널 생성 및 피어 채널 참석 4번 ~ 5번
1. createChannel.sh파일을 요청함으로 해당 파일 조건에 맞게 수정
2. createChannel.sh파일 내부에 envVar.sh파일 조건에 맞게 수정

### 체인코드 배포
1. 기존 체인코드 수정
2. 체인코드 패키지 생성
3. 체인코드 각 피어 설치
4. 조직별 체인코드 승인
5. 작동 확인

### Dapp 제작 및 연결