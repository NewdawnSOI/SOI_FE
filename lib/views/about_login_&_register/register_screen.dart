import 'dart:async';

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:soi/api/api_exception.dart';
import 'package:soi/api/controller/user_controller.dart';
import 'package:soi/utils/username_validator.dart';
import 'package:soi/utils/snackbar_utils.dart';
import 'package:soi/views/about_login_&_register/widgets/pages/agreement_page.dart';
import 'package:soi/views/about_login_&_register/services/register_phone_number_service.dart';
import 'package:soi/views/about_login_&_register/widgets/pages/phone_input_page.dart';
import 'package:soi/views/about_login_&_register/widgets/pages/sms_code_page.dart';
import 'auth_final_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'widgets/common/continue_button.dart';
import 'widgets/pages/friend_add_and_share_page.dart';
import 'widgets/pages/name_input_page.dart';
import 'widgets/pages/birth_date_page.dart';
import 'widgets/pages/select_profile_image_page.dart';
import 'widgets/pages/id_input_page.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final PageController _pageController = PageController();

  // 자동 인증을 위한 Timer
  Timer? _autoVerifyTimer;

  // 사용자가 존재하는지 여부 및 상태 관리
  bool userExists = false;
  bool isVerified = false;
  bool isCheckingUser = false;
  bool _isRequestingSms = false;

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
  String _selectedCountryCode = 'KR';

  // 공통 컨트롤러
  late TextEditingController nameController;
  late TextEditingController monthController;
  late TextEditingController dayController;
  late TextEditingController yearController;
  late TextEditingController phoneController;
  late TextEditingController smsController;
  late TextEditingController idController;

  // 중복 아이디 체크를 위한 변수
  String? _idErrorKey;
  bool? _isIdAvailable;
  String? _phoneErrorKey;
  Timer? debounceTimer;

  // 약관 동의 상태 변수들
  bool agreeAll = false;
  bool agreeServiceTerms = false;
  bool agreePrivacyTerms = false;
  bool agreeMarketingInfo = false;

  // userController만 사용하여서 UI에서 직접 접근
  late UserController _userController;
  bool _isControllerInitialized = false;

  /// 현재 선택 국가가 레거시 API SMS fallback을 쓰는지 계산합니다.
  bool get _usesApiPhoneVerification =>
      RegisterPhoneNumberService.usesApiSmsVerification(
        countryCode: _selectedCountryCode,
      );

  /// 현재 선택 국가가 요구하는 인증번호 자리수를 버튼 활성화와 입력 제한에 함께 사용합니다.
  int get _expectedSmsCodeLength => _usesApiPhoneVerification ? 5 : 6;

  /// 현재 인증 채널이 Firebase일 때만 자동 인증 완료 상태를 회원가입 단계 전환에 재사용합니다.
  bool get _isCurrentPhoneVerificationCompleted =>
      !_usesApiPhoneVerification &&
      _userController.isPhoneVerificationCompleted;

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

    pageReady[6].value = true;
    pageReady[7].value = true; // 친구 추가 페이지는 선택 사항이므로 항상 활성화

    // ID 컨트롤러 리스너 추가
    idController.addListener(() {
      if (!_isControllerInitialized) return; // Provider 초기화 전이면 무시
      if (debounceTimer?.isActive ?? false) debounceTimer!.cancel();
      debounceTimer = Timer(const Duration(milliseconds: 300), () async {
        final id = idController.text.trim();
        if (isForbiddenUsername(id)) {
          setState(() {
            _idErrorKey = 'register.id_not_allowed';
            _isIdAvailable = false;
          });
          return;
        }
        if (id.isNotEmpty) {
          try {
            final result = await _userController.checknickNameAvailable(id);
            if (result == true) {
              setState(() {
                _idErrorKey = 'register.id_available';
                _isIdAvailable = true;
              });
            } else {
              setState(() {
                _idErrorKey = 'register.id_unavailable';
                _isIdAvailable = false;
              });
            }
          } catch (e) {
            setState(() {
              _idErrorKey = 'register.id_check_error';
              _isIdAvailable = false;
            });
          }
        } else {
          setState(() {
            _idErrorKey = null;
            _isIdAvailable = null;
          });
        }
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isControllerInitialized) {
      _userController = Provider.of<UserController>(context, listen: false);
      _isControllerInitialized = true;
    }
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
  /// 회원가입 각 단계를 PageView로 조립하고 전화번호 인증 흐름까지 한 화면에서 연결합니다.
  Widget build(BuildContext context) {
    // 화면 크기 정보
    final double screenHeight = MediaQuery.of(context).size.height;

    final String? idErrorMessage = _idErrorKey == null
        ? null
        : tr(_idErrorKey!, context: context);

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
                if (index == 4 || index == 5) {
                  pageReady[4].value = true;
                  pageReady[5].value = true;
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
                    // 서버 API 형식에 맞게 YYYY.MM.DD 형식으로 저장
                    final month = (selectedMonth ?? '').padLeft(2, '0');
                    final day = (selectedDay ?? '').padLeft(2, '0');
                    birthDate = "${selectedYear ?? ''}.$month.$day";

                    // 모든 필드가 채워졌는지 확인
                    bool isComplete =
                        monthController.text.isNotEmpty &&
                        dayController.text.isNotEmpty &&
                        yearController.text.isNotEmpty;
                    pageReady[1].value = isComplete;
                  });
                },
                onSkip: () {
                  FocusScope.of(context).unfocus();
                  setState(() {
                    monthController.clear();
                    dayController.clear();
                    yearController.clear();
                    selectedMonth = null;
                    selectedDay = null;
                    selectedYear = null;
                    birthDate = '';
                    pageReady[1].value = false;
                  });
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
              ),

              // 3. 전화번호 입력 페이지
              PhoneInputPage(
                controller: phoneController,
                onChanged: _handlePhoneInputChanged,
                selectedCountryCode: _selectedCountryCode,
                onCountryChanged: _handleCountryChanged,
                maxLength: RegisterPhoneNumberService.maxInputLength(
                  countryCode: _selectedCountryCode,
                ),
                errorText: _phoneErrorKey == null
                    ? null
                    : tr(_phoneErrorKey!, context: context),
                pageController: _pageController,
              ),
              // 인증번호 입력 페이지
              SmsCodePage(
                controller: smsController,
                maxCodeLength: _expectedSmsCodeLength,
                onChanged: (value) {
                  pageReady[3].value = value.length == _expectedSmsCodeLength;

                  // 인증 완료 후, 사용자가 인증번호를 변경하면 상태 초기화
                  if (isVerified) {
                    setState(() {
                      isVerified = false;
                    });
                  }
                },
                // 기존 API 재전송 흐름은 화면에서 아래처럼 직접 요청/에러 처리를 수행했습니다.
                // onResendPressed: () async {
                //   try {
                //     final formattedPhone = _formatPhoneNumberForApi(
                //       withCountryCode: true,
                //     );
                //     phoneNumber = formattedPhone;
                //
                //     await _userController
                //         .requestSmsVerification(formattedPhone)
                //         .onError((error, stackTrace) {
                //           throw Exception('SMS 재전송 실패: $error');
                //         });
                //   } catch (e) {
                //     SnackBarUtils.showSnackBar(
                //       context,
                //       '인증번호 재전송 중 오류가 발생했습니다.',
                //     );
                //     debugPrint('재전송 예외: $e');
                //   }
                // },
                //
                // Firebase 인증 흐름에서는 재전송도 동일한 메서드로 처리하므로,
                // 버튼에서 직접 재인증 요청을 수행하도록 합니다.
                onResendPressed: () =>
                    _requestPhoneVerification(isResend: true),
                isBusy: _isRequestingSms,
                pageController: _pageController,
              ),
              // 3. 아이디 입력 페이지
              IdInputPage(
                controller: idController,
                screenHeight: screenHeight,
                errorMessage: idErrorMessage,
                isAvailable: _isIdAvailable,
                onChanged: (value) {
                  pageReady[4].value = value.isNotEmpty;
                },
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    if (isForbiddenUsername(value)) {
                      setState(() {
                        _idErrorKey = 'register.id_not_allowed';
                        _isIdAvailable = false;
                      });
                      return;
                    }
                    id = value;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AuthFinalScreen(
                          id: id,
                          name: name,
                          phone: _formatPhoneNumberForApi(),
                          birthDate: birthDate,
                        ),
                      ),
                    );
                  }
                },
                pageController: _pageController,
              ),
              // 4. 약관동의 페이지
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
              // 5. 프로필 이미지 선택 페이지
              SelectProfileImagePage(
                onImageSelected: (String? imagePath) {
                  setState(() {
                    profileImagePath = imagePath;

                    // 이미지 선택은 선택사항이므로 항상 true
                    pageReady[6].value = true;
                  });
                },
                pageController: _pageController,
                onSkip: _navigateToAuthFinal,
              ),
              // 6. 친구 추가 및 공유 페이지
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
                final bool isBusy = isCheckingUser || _isRequestingSms;
                final bool isEnabled =
                    !isBusy &&
                    ready &&
                    (currentPage != 4 ||
                        idErrorMessage == null ||
                        _isIdAvailable == true);

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
                              // 기존 API 전화번호 인증 로직
                              // final formattedPhone = _formatPhoneNumberForApi(
                              //   rawValue: phoneController.text,
                              //   withCountryCode: true,
                              // );
                              // phoneNumber = formattedPhone;
                              // try {
                              //   final isSuccess = await _userController
                              //       .requestSmsVerification(formattedPhone);
                              //
                              //   if (isSuccess) {
                              //     _pageController.nextPage(
                              //       duration: const Duration(milliseconds: 300),
                              //       curve: Curves.easeInOut,
                              //     );
                              //   } else {
                              //     if (mounted) {
                              //       SnackBarUtils.showSnackBar(
                              //         context,
                              //         'SMS 발송에 실패했습니다. 다시 시도해주세요.',
                              //       );
                              //     }
                              //   }
                              // } catch (e) {
                              //   if (mounted) {
                              //     SnackBarUtils.showSnackBar(
                              //       context,
                              //       'SMS 발송 중 오류가 발생했습니다.',
                              //     );
                              //   }
                              //   debugPrint('SMS 발송 예외: $e');
                              // }
                              //
                              // Firebase 인증 흐름에서는 전화번호 인증 요청도 별도 메서드로 분리하여 처리합니다.
                              await _requestPhoneVerification();
                              break;
                            case 3: // 인증코드
                              smsCode = smsController.text;
                              if (smsCode.length == _expectedSmsCodeLength ||
                                  _isCurrentPhoneVerificationCompleted) {
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
                            case 6: // 프로필 이미지
                              _pageController.nextPage(
                                duration: Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                              break;
                            case 7: // 친구 추가
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

  /// 전화번호 입력값을 국가별 규칙으로 검증해 버튼 활성화와 에러 메시지를 함께 갱신합니다.
  void _handlePhoneInputChanged(String value) {
    final validationError = RegisterPhoneNumberService.validatePhone(
      rawValue: value,
      countryCode: _selectedCountryCode,
    );
    _resetPendingPhoneVerification();

    setState(() {
      _phoneErrorKey = validationError?.translationKey;
      isVerified = false;
    });
    pageReady[2].value = value.trim().isNotEmpty && validationError == null;
    pageReady[3].value = false;
  }

  /// 국가가 바뀌면 같은 입력값도 다시 해석해야 하므로 전화번호 검증 결과를 즉시 재계산합니다.
  void _handleCountryChanged(String countryCode) {
    final validationError = RegisterPhoneNumberService.validatePhone(
      rawValue: phoneController.text,
      countryCode: countryCode,
    );
    _resetPendingPhoneVerification();

    setState(() {
      _selectedCountryCode = countryCode;
      _phoneErrorKey = validationError?.translationKey;
      isVerified = false;
    });
    pageReady[2].value =
        phoneController.text.trim().isNotEmpty && validationError == null;
    pageReady[3].value = false;
  }

  /// 선택 국가에 맞는 인증 채널로 SMS를 요청하고 필요 시 SMS 입력 또는 자동 완료 흐름으로 분기합니다.
  ///
  /// Parameters:
  /// - [isResend]: 재전송 요청 여부 (기본값: false)
  ///
  /// Returns:
  /// - `Future<void>`: 인증 요청 처리 완료를 나타내는 Future
  Future<void> _requestPhoneVerification({bool isResend = false}) async {
    if (_isRequestingSms) {
      return;
    }

    final validationError = RegisterPhoneNumberService.validatePhone(
      rawValue: phoneController.text,
      countryCode: _selectedCountryCode,
    );
    if (validationError != null) {
      final errorKey = validationError.translationKey;
      setState(() {
        _phoneErrorKey = errorKey;
      });
      SnackBarUtils.showSnackBar(context, tr(errorKey, context: context));
      return;
    }

    // 서버 API는 로컬 번호를, Firebase SMS는 국가 코드가 포함된 E.164 번호를 각각 사용합니다.
    final formattedPhoneForApi = _formatPhoneNumberForApi(
      rawValue: phoneController.text,
    );
    final formattedPhoneForFirebase = _formatPhoneNumberForApi(
      rawValue: phoneController.text,
      withCountryCode: true,
    );

    // userController.userCreate API에 전달할 전화번호를 저장합니다.
    // 이 값은 Firebase 인증과 별도로 서버 API에 전달될 때 사용됩니다.
    phoneNumber = formattedPhoneForApi;
    final useFirebase = !_usesApiPhoneVerification;
    final verificationPhoneNumber = useFirebase
        ? formattedPhoneForFirebase
        : formattedPhoneForApi;
    if (_userController.shouldResetPhoneVerificationState(
      verificationPhoneNumber,
      useFirebase: useFirebase,
    )) {
      _resetPendingPhoneVerification();
    }

    setState(() {
      _isRequestingSms = true;
    });

    try {
      final isSuccess = await _userController.requestSmsVerification(
        verificationPhoneNumber,
        useFirebase: useFirebase,
      );
      if (!mounted) return;

      if (!isSuccess) {
        SnackBarUtils.showSnackBar(
          context,
          _userController.errorMessage ??
              (isResend
                  ? '인증번호 재전송 중 오류가 발생했습니다.'
                  : 'SMS 발송에 실패했습니다. 다시 시도해주세요.'),
        );
        return;
      }

      smsController.clear();
      setState(() {
        isVerified = _isCurrentPhoneVerificationCompleted;
        pageReady[3].value = false;
      });

      if (_isCurrentPhoneVerificationCompleted) {
        await _handleSuccessfulPhoneVerification();
        return;
      }

      // SMS 입력 페이지로 이동합니다.
      // 재전송 시에는 이미 같은 페이지에 있으므로 이동하지 않습니다.
      if (!isResend) {
        await _pageController.nextPage(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }

      if (useFirebase) {
        _startAutoVerificationWatcher();
      }
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showSnackBar(
        context,
        _resolveAuthErrorMessage(
          e,
          fallback: isResend
              ? '인증번호 재전송 중 오류가 발생했습니다.'
              : 'SMS 발송 중 오류가 발생했습니다.',
        ),
      );
      debugPrint(isResend ? '재전송 예외: $e' : 'SMS 발송 예외: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRequestingSms = false;
        });
      } else {
        _isRequestingSms = false;
      }
    }
  }

  /// 전화번호나 국가가 바뀌면 이전 인증 채널의 대기 상태를 비워 다음 요청과 섞이지 않게 합니다.
  void _resetPendingPhoneVerification() {
    _autoVerifyTimer?.cancel();
    smsController.clear();
    _userController.resetPhoneVerificationState();
  }

  /// SMS 입력 대기 중 Firebase 즉시 인증이 완료되면 다음 회원가입 단계로 자동 이동시킵니다.
  void _startAutoVerificationWatcher() {
    if (_usesApiPhoneVerification) {
      return;
    }

    _autoVerifyTimer?.cancel();
    _autoVerifyTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || currentPage != 3) {
        timer.cancel();
        return;
      }

      if (!_isCurrentPhoneVerificationCompleted) {
        return;
      }

      timer.cancel();

      unawaited(_handleSuccessfulPhoneVerification());
    });
  }

  /// 전화번호 인증이 완료되면 상태와 페이지를 정리하고 아이디 입력 단계로 이동합니다.
  Future<void> _handleSuccessfulPhoneVerification() async {
    _autoVerifyTimer?.cancel();
    if (!mounted) return;

    setState(() {
      isCheckingUser = false;
      isVerified = true;
      pageReady[3].value = true;
    });

    SnackBarUtils.showSnackBar(context, '인증이 완료되었습니다.');
    FocusScope.of(context).unfocus();
    await _pageController.animateToPage(
      4,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// 사용자가 입력한 SMS 코드를 현재 국가가 선택한 인증 채널에 전달해 최종 인증 여부를 확정합니다.
  Future<void> _performManualVerification(String code) async {
    if (isCheckingUser) return;
    _autoVerifyTimer?.cancel();

    if (_isCurrentPhoneVerificationCompleted) {
      await _handleSuccessfulPhoneVerification();
      return;
    }

    setState(() {
      isCheckingUser = true;
    });

    smsCode = code;

    try {
      final useFirebase = !_usesApiPhoneVerification;
      final isSuccess = await _userController.verifySmsCode(
        useFirebase
            ? _formatPhoneNumberForApi(withCountryCode: true)
            : _formatPhoneNumberForApi(),
        smsCode,
        useFirebase: useFirebase,
      );

      if (!mounted) return;
      if (isSuccess) {
        await _handleSuccessfulPhoneVerification();
      } else {
        setState(() {
          isCheckingUser = false;
          isVerified = false;
        });
        if (mounted) {
          SnackBarUtils.showSnackBar(context, '인증번호가 올바르지 않습니다.');
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isCheckingUser = false;
        isVerified = false;
      });

      // 기존 API 예외 처리에서는 화면에 보여줄 메시지를 직접 가공했습니다.
      // final errorMessage = e.toString().replaceFirst('Exception: ', '').trim();
      // if (mounted) {
      //   SnackBarUtils.showSnackBar(
      //     context,
      //     errorMessage.isNotEmpty ? errorMessage : '인증 확인 중 오류가 발생했습니다.',
      //   );
      // }
      SnackBarUtils.showSnackBar(
        context,
        _resolveAuthErrorMessage(e, fallback: '인증 확인 중 오류가 발생했습니다.'),
      );
      debugPrint('인증 확인 중 예외: $e');
    }
  }

  /// 인증 흐름 예외를 화면 메시지로 바꿔 사용자가 실패 원인을 바로 확인할 수 있게 합니다.
  String _resolveAuthErrorMessage(Object error, {required String fallback}) {
    if (error is SoiApiException) {
      final message = error.message.trim();
      if (message.isNotEmpty) {
        return message;
      }
    }

    final rawMessage = error.toString().trim();
    if (rawMessage.isEmpty) {
      return fallback;
    }

    final normalized = rawMessage
        .replaceFirst('Exception: ', '')
        .replaceFirst('SoiApiException: ', '')
        .trim();
    return normalized.isEmpty ? fallback : normalized;
  }

  // 전체 동의 상태 업데이트 함수
  void _updateAgreeAllStatus() {
    agreeAll = agreeServiceTerms && agreePrivacyTerms && agreeMarketingInfo;
  }

  /// 전화번호 입력값을 서버 API용 로컬 번호 또는 Firebase용 E.164 번호로 정규화합니다.
  ///
  /// Parameters:
  /// - [rawValue]: 변환할 원본 전화번호 문자열 (기본값: phoneNumber 상태값)
  /// - [withCountryCode]: 국가 코드 포함 여부 (기본값: false)
  ///
  /// Returns:
  /// - [String]: API 요구사항에 맞게 변환된 전화번호 문자열
  ///   - 국가 코드 포함 시: +821012345678 같은 E.164 형식
  ///   - 국가 코드 미포함 시: 01012345678 같은 로컬 형식
  String _formatPhoneNumberForApi({
    String? rawValue,
    bool withCountryCode = false,
  }) {
    final source = (rawValue ?? phoneNumber).trim();
    final fallbackSource = source.isNotEmpty ? source : phoneController.text;

    if (withCountryCode) {
      return RegisterPhoneNumberService.formatE164Phone(
        rawValue: fallbackSource,
        countryCode: _selectedCountryCode,
      );
    }
    return RegisterPhoneNumberService.formatLocalPhone(
      rawValue: fallbackSource,
      countryCode: _selectedCountryCode,
    );
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
          phone: _formatPhoneNumberForApi(),
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
