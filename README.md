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
1. CA 기본 구축(MSP) -> CA1 CA2
2. 오더링 서비스 3개 구축
3. configuration block 설정
4. 채널 생성
5. 피어 채널 참석
6. 체인코드 배포
7. DApp 연결