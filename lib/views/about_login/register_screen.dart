import 'dart:async';
import 'package:flutter/material.dart';
import 'package:soi/views/about_login/widgets/pages/agreement_page.dart';
import '../../api/services/user_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'auth_final_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'widgets/common/continue_button.dart';
import 'widgets/pages/friend_add_and_share_page.dart';
import 'widgets/pages/name_input_page.dart';
import 'widgets/pages/birth_date_page.dart';
import 'widgets/pages/phone_input_page.dart';
import 'widgets/pages/select_profile_image_page.dart';
import 'widgets/pages/sms_code_page.dart';
import 'widgets/pages/id_input_page.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final PageController _pageController = PageController();
  final UserService _userService = UserService();

  // 자동 인증을 위한 Timer
  Timer? _autoVerifyTimer;

  // 사용자가 존재하는지 여부 및 상태 관리
  bool userExists = false;
  bool isVerified = false;
  bool isCheckingUser = false;

  // 입력 데이터
  String phoneNumber = '';
  String smsCode = '';
  String name = '';
  String birthDate = '';
  String id = '';
  String? profileImagePath;

  // 현재 페이지 인덱스
  int currentPage = 0;

  // 드롭다운에서 선택된 값
  String? selectedYear;
  String? selectedMonth;
  String? selectedDay;

  // 페이지별 입력 완료 여부
  late List<ValueNotifier<bool>> pageReady;

  // 공통 컨트롤러
  late TextEditingController nameController;
  late TextEditingController monthController;
  late TextEditingController dayController;
  late TextEditingController yearController;
  late TextEditingController phoneController;
  late TextEditingController smsController;
  late TextEditingController idController;

  // 중복 아이디 체크를 위한 변수
  String? idErrorMessage;
  Timer? debounceTimer;

  // 약관 동의 상태 변수들
  bool agreeAll = false;
  bool agreeServiceTerms = false;
  bool agreePrivacyTerms = false;
  bool agreeMarketingInfo = false;

  @override
  void initState() {
    super.initState();
    // 컨트롤러 및 상태 초기화
    nameController = TextEditingController();
    monthController = TextEditingController();
    dayController = TextEditingController();
    yearController = TextEditingController();
    phoneController = TextEditingController();
    smsController = TextEditingController();
    idController = TextEditingController();
    pageReady = List.generate(8, (_) => ValueNotifier<bool>(false));

    // UserService는 이미 초기화됨

    // ID 컨트롤러 리스너 추가
    idController.addListener(() {
      if (debounceTimer?.isActive ?? false) debounceTimer!.cancel();
      debounceTimer = Timer(const Duration(milliseconds: 300), () async {
        final id = idController.text.trim();
        if (id.isNotEmpty) {
          try {
            final result = await _userService.checkUserIdDuplicate(id);
            result.when(
              success: (isAvailable) {
                setState(() {
                  idErrorMessage = isAvailable
                      ? '사용 가능한 아이디입니다.'
                      : '이미 사용 중인 아이디입니다.';
                });
              },
              failure: (error) {
                setState(() {
                  idErrorMessage = '중복 확인 중 오류가 발생했습니다.';
                });
              },
            );
          } catch (e) {
            setState(() {
              idErrorMessage = '중복 확인 중 오류가 발생했습니다.';
            });
          }
        } else {
          setState(() {
            idErrorMessage = null;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    // Dispose controllers and notifiers
    nameController.dispose();
    monthController.dispose();
    dayController.dispose();
    yearController.dispose();
    phoneController.dispose();
    smsController.dispose();
    idController.dispose();
    for (var notifier in pageReady) {
      notifier.dispose();
    }
    _autoVerifyTimer?.cancel();
    debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 화면 크기 정보
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,

      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            physics: NeverScrollableScrollPhysics(),
            onPageChanged: (index) {
              setState(() {
                currentPage = index;
                if (index == 7) {
                  pageReady[7].value = true;
                }
              });
            },
            children: [
              // 1. 이름 입력 페이지
              NameInputPage(
                controller: nameController,
                onChanged: (value) {
                  pageReady[0].value = value.isNotEmpty;
                },
              ),
              // 2. 생년월일 입력 페이지
              BirthDatePage(
                monthController: monthController,
                dayController: dayController,
                yearController: yearController,
                pageController: _pageController,
                onChanged: () {
                  setState(() {
                    selectedMonth = monthController.text;
                    selectedDay = dayController.text;
                    selectedYear = yearController.text;
                    birthDate =
                        "${selectedYear ?? ''}년 ${selectedMonth ?? ''}월 ${selectedDay ?? ''}일";

                    // 모든 필드가 채워졌는지 확인
                    bool isComplete =
                        monthController.text.isNotEmpty &&
                        dayController.text.isNotEmpty &&
                        yearController.text.isNotEmpty;
                    pageReady[1].value = isComplete;
                  });
                },
              ),
              // 3. 전화번호 입력 페이지
              PhoneInputPage(
                controller: phoneController,
                onChanged: (value) {
                  pageReady[2].value = value.isNotEmpty;
                },
                pageController: _pageController,
              ),
              // 인증번호 입력 페이지
              SmsCodePage(
                controller: smsController,
                onChanged: (value) {
                  // 인증번호 입력 여부에 따라 상태 변경
                  pageReady[3].value = value.length >= 6;

                  // 인증 완료 후, 사용자가 인증번호를 변경하면 상태 초기화
                  if (isVerified) {
                    setState(() {
                      isVerified = false;
                    });
                  }
                },
                onResendPressed: () async {
                  // 인증번호 재전송 로직
                  try {
                    final result = await _userService.sendAuthSMS(phoneNumber);
                    result.when(
                      success: (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('인증번호가 재전송되었습니다.')),
                        );
                      },
                      failure: (error) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('인증번호 재전송에 실패했습니다.')),
                        );
                      },
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('인증번호 재전송 중 오류가 발생했습니다.')),
                    );
                  }
                },
                pageController: _pageController,
              ),
              // 4. 아이디 입력 페이지
              IdInputPage(
                controller: idController,
                screenHeight: screenHeight,
                errorMessage: idErrorMessage,
                onChanged: (value) {
                  pageReady[4].value = value.isNotEmpty;
                },
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    id = value;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AuthFinalScreen(
                          id: id,
                          name: name,
                          phone: phoneNumber,
                          birthDate: birthDate,
                        ),
                      ),
                    );
                  }
                },
                pageController: _pageController,
              ),
              // 5. 약관동의 페이지
              AgreementPage(
                name: name,
                agreeAll: agreeAll,
                agreeServiceTerms: agreeServiceTerms,
                agreePrivacyTerms: agreePrivacyTerms,
                agreeMarketingInfo: agreeMarketingInfo,
                onToggleAll: (bool value) {
                  setState(() {
                    agreeAll = value;
                    // 전체 동의 시 모든 개별 항목도 함께 변경
                    agreeServiceTerms = value;
                    agreePrivacyTerms = value;
                    agreeMarketingInfo = value;
                    // 약관 페이지 준비 상태 업데이트 (필수 약관이 모두 체크되었는지 확인)
                    pageReady[5].value = agreeServiceTerms && agreePrivacyTerms;
                  });
                },
                onToggleServiceTerms: (bool value) {
                  setState(() {
                    agreeServiceTerms = value;
                    // 개별 항목 변경 시 전체 동의 상태 업데이트
                    _updateAgreeAllStatus();
                    pageReady[5].value = agreeServiceTerms && agreePrivacyTerms;
                  });
                },
                onTogglePrivacyTerms: (bool value) {
                  setState(() {
                    agreePrivacyTerms = value;
                    // 개별 항목 변경 시 전체 동의 상태 업데이트
                    _updateAgreeAllStatus();
                    pageReady[5].value = agreeServiceTerms && agreePrivacyTerms;
                  });
                },
                onToggleMarketingInfo: (bool value) {
                  setState(() {
                    agreeMarketingInfo = value;
                    // 개별 항목 변경 시 전체 동의 상태 업데이트
                    _updateAgreeAllStatus();
                  });
                },
                pageController: _pageController,
              ),
              // 6. 프로필 이미지 선택 페이지
              SelectProfileImagePage(
                onImageSelected: (String? imagePath) {
                  setState(() {
                    profileImagePath = imagePath;
                    pageReady[6].value = true; // 이미지 선택은 선택사항이므로 항상 true
                  });
                },
                pageController: _pageController,
                onSkip: _navigateToAuthFinal,
              ),
              // 7. 친구 추가 및 공유 페이지
              FriendAddAndSharePage(
                pageController: _pageController,
                onSkip: _navigateToAuthFinal,
              ),
            ],
          ),

          // 공통 Continue 버튼
          Positioned(
            bottom: MediaQuery.of(context).viewInsets.bottom > 0
                ? MediaQuery.of(context).viewInsets.bottom + 20.h
                : 30.h,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<bool>(
              valueListenable: pageReady[currentPage],
              builder: (context, ready, child) {
                final bool isEnabled =
                    ready &&
                    (currentPage != 4 ||
                        idErrorMessage == null ||
                        idErrorMessage == '사용 가능한 아이디입니다.');

                return ContinueButton(
                  isEnabled: isEnabled,
                  onPressed: isEnabled
                      ? () async {
                          FocusScope.of(context).unfocus();
                          switch (currentPage) {
                            case 0: // 이름
                              name = nameController.text;
                              _pageController.nextPage(
                                duration: Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                              break;
                            case 1: // 생년월일
                              _pageController.nextPage(
                                duration: Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                              break;
                            case 2: // 전화번호
                              phoneNumber = phoneController.text;
                              debugPrint('전화번호 입력: "$phoneNumber"');

                              try {
                                final result = await _userService.sendAuthSMS(
                                  phoneNumber,
                                );
                                result.when(
                                  success: (success) {
                                    // SMS 발송 성공시 다음 페이지로 이동
                                    _pageController.nextPage(
                                      duration: Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                  failure: (error) {
                                    Fluttertoast.showToast(
                                      msg: 'SMS 발송에 실패했습니다.',
                                      backgroundColor: Colors.red,
                                      textColor: Colors.white,
                                    );
                                  },
                                );
                              } catch (e) {
                                Fluttertoast.showToast(
                                  msg: 'SMS 발송 중 오류가 발생했습니다.',
                                  backgroundColor: Colors.red,
                                  textColor: Colors.white,
                                );
                              }
                              break;
                            case 3: // 인증코드
                              smsCode = smsController.text;

                              // 버튼 클릭시 인증 확인 수행
                              if (smsCode.length >= 6) {
                                await _performManualVerification(smsCode);
                              }
                              break;
                            case 4: // 아이디
                              id = idController.text;
                              // ID 저장 후 다음 페이지로 이동
                              _pageController.nextPage(
                                duration: Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                              break;
                            case 5: // 약관동의
                              _pageController.nextPage(
                                duration: Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                              break;
                            // 여기서 프로필 설정 페이지로 넘어가야함
                            case 6:
                              _pageController.nextPage(
                                duration: Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                              break;
                            case 7:
                              _navigateToAuthFinal();
                              break;
                          }
                        }
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 수동 인증 수행 함수 (버튼 클릭 시)
  Future<void> _performManualVerification(String code) async {
    if (isCheckingUser) return;

    setState(() {
      isCheckingUser = true;
    });

    // SMS 코드 저장
    smsCode = code;

    // 디버깅: 전송할 값 로그
    debugPrint('🔍 인증 확인 시도 - phoneNumber: "$phoneNumber", code: "$code"');

    try {
      // API를 통한 SMS 코드 검증
      final result = await _userService.checkAuthSMS(
        phoneNumber: phoneNumber,
        code: code,
      );

      result.when(
        success: (isValid) {
          debugPrint('인증 확인 API 응답: $isValid');
          if (isValid) {
            // 인증 성공
            setState(() {
              isCheckingUser = false;
              isVerified = true;
            });

            Fluttertoast.showToast(
              msg: '인증이 완료되었습니다.',
              backgroundColor: Colors.green,
              textColor: Colors.white,
            );

            // 검증 완료 후 다음 페이지로 이동
            FocusScope.of(context).unfocus();
            _pageController.nextPage(
              duration: Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          } else {
            // 인증 실패 (코드가 틀림)
            setState(() {
              isCheckingUser = false;
              isVerified = false;
            });

            Fluttertoast.showToast(
              msg: '인증번호가 일치하지 않습니다.',
              backgroundColor: Colors.red,
              textColor: Colors.white,
            );
          }
        },
        failure: (error) {
          // API 에러 처리
          setState(() {
            isCheckingUser = false;
            isVerified = false;
          });

          Fluttertoast.showToast(
            msg: '인증 확인 중 오류가 발생했습니다.\n${error.message}',
            backgroundColor: Colors.red,
            textColor: Colors.white,
            toastLength: Toast.LENGTH_LONG,
          );

          debugPrint('❌ 인증 확인 중 오류: ${error.message}');
        },
      );
    } catch (e) {
      // 예외 처리
      setState(() {
        isCheckingUser = false;
        isVerified = false;
      });

      Fluttertoast.showToast(
        msg: '인증 확인 중 오류가 발생했습니다.',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );

      debugPrint('❌ 인증 확인 중 예외: $e');
    }
  }

  // 전체 동의 상태 업데이트 함수
  void _updateAgreeAllStatus() {
    agreeAll = agreeServiceTerms && agreePrivacyTerms && agreeMarketingInfo;
  }

  void _navigateToAuthFinal() {
    // 회원가입 데이터를 AuthFinalScreen으로 전달
    // 실제 회원가입은 onboarding 완료 후 수행
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AuthFinalScreen(
          id: id,
          name: name,
          phone: phoneNumber,
          birthDate: birthDate,
          profileImagePath: profileImagePath,
          agreeServiceTerms: agreeServiceTerms,
          agreePrivacyTerms: agreePrivacyTerms,
          agreeMarketingInfo: agreeMarketingInfo,
        ),
      ),
    );
  }
}
