import 'dart:async';

import 'package:dd_player/defs.dart';
import 'package:dd_player/utils/overlay.dart';
import 'package:dd_player/channel/screen.dart';
import 'package:dd_player/utils/lifecycle_event_handler.dart';
import 'package:dd_player/channel/volume.dart';
import 'package:dd_player/utils/pair.dart';
import 'package:dd_player/widgets/fixed_video.dart';
import 'package:dd_player/widgets/player_popup_animated.dart';
import 'package:dd_player/widgets/slide_transition_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_dlna/flutter_dlna.dart';

class VideoView extends StatefulWidget {
  VideoPlayerController controller;
  bool isFullScreenMode = false;
  Widget thumbnail;
  Function listener;
  bool enableDLNA;
  bool enablePip;
  bool enableFixed;
  String title;
  double speed;

  VideoView({
    Key key,
    this.title,
    this.controller,
    this.thumbnail,
    this.listener,
    this.isFullScreenMode = false,
    this.enableDLNA = false,
    this.enablePip = false,
    this.enableFixed = false,
    this.speed=1.0,
  }) : super(key: key);

  @override
  _VideoView createState() => _VideoView();
}

class _VideoView extends State<VideoView> with TickerProviderStateMixin {
  VideoPlayerController get _videoPlayerController => widget.controller;

  set _videoPlayerController(v) => widget.controller = v;

  bool get _isFullScreenMode => widget.isFullScreenMode;

  Widget get _thumbnail => widget.thumbnail;

  Function get _listener => widget.listener;

  bool get _enableDLNA => widget.enableDLNA;

  bool get _enablePip => widget.enablePip;

  bool get _enableFixed => widget.enableFixed;

  bool _isHiddenControls = true;
  bool _isLocked = false;
  bool _isShowPopup = false;
  double _popupWidth = 260.0;
  DeviceOrientation _defaultFullScreenOrientation =
      DeviceOrientation.landscapeLeft;
  Timer _timer;
  AnimationController _animationController;
  Animation<double> _animation;
  AnimationController _slideTopAnimationController;
  Animation<double> _slideTopAnimation;
  AnimationController _slideBottomAnimationController;
  Animation<double> _slideBottomAnimation;

  List<dynamic> _devices = [];
  PopupType _popupType = PopupType.none;

  List<Pair<String, double>> speeds = [new Pair("x1", 1.0), new Pair("x1.5", 1.5), new Pair("x2", 2.0)];
  int speedSelected = 0;

  double _panStartX = 0.0;
  double _panStartY = 0.0;
  int _lastSourceTimeStamp = 0;
  int _currentBrightness = 0;
  int _currentVolume = 0;
  int _maxVolume = 1;
  bool _showBrightnessInfo = false;
  bool _showVolumeInfo = false;
  bool _showPositionInfo = false;
  int _preLoadPosition = 0;
  bool _isMute = false;

  bool _isBackgroundMode = false;
  WidgetsBindingObserver _widgetsBindingObserver;

  Widget build(BuildContext context) {
    if (_videoPlayerController?.value != null) {
      if (_videoPlayerController.value.initialized) {
        return _buildWrapPop(_buildVideo());
      }
      if (_videoPlayerController.value.hasError &&
          !_videoPlayerController.value.isPlaying) {
        return _buildWrapPop(_buildMask(errMsg: "加载失败,请稍后再试!"));
      }
      return _buildWrapPop(_buildMask(isLoading: true));
    }
    return _buildWrapPop(_buildMask());
  }

  Widget _buildWrapPop(Widget child) {
    if (!_isFullScreenMode && !_enableFixed) {
      return child;
    }
    return WillPopScope(
      child: child,
      onWillPop: () async {
        // if (!_isFullScreenMode) {
          if (_enableFixed) {
            _showOverlay();
          }
        //   return true;
        // }
        if (!_isLocked) {
          _exitFullScreen();
          return false;
        }
        return !_isLocked;
      },
    );
  }

  String get _formatPosition {
    return _formatTime(
        _videoPlayerController.value.position.inSeconds.toDouble());
  }

  String get _formatDuration {
    return _formatTime(
        _videoPlayerController.value.duration.inSeconds.toDouble());
  }

  String get _formatPrePosition {
    return _formatTime(_preLoadPosition.toDouble());
  }

  String get _volumePercentage {
    return (_currentVolume / _maxVolume * 100).toInt().toString();
  }

  double get _position {
    double position =
        _videoPlayerController.value.position.inSeconds.toDouble();
    // fix live
    if (position >= _duration) {
      return _duration;
    }
    return position;
  }

  double get _duration {
    double duration =
        _videoPlayerController.value.duration.inSeconds.toDouble();
    return duration;
  }

  @override
  void initState() {
    _animationController =
        AnimationController(duration: Duration(milliseconds: 200), vsync: this);
    _slideTopAnimationController =
        AnimationController(duration: Duration(milliseconds: 200), vsync: this);
    _slideBottomAnimationController =
        AnimationController(duration: Duration(milliseconds: 200), vsync: this);
    _animation =
        new Tween(begin: -_popupWidth, end: 0.0).animate(_animationController)
          ..addStatusListener((state) {
            if (!mounted) {
              return;
            }
            if (state == AnimationStatus.forward) {
              setState(() {
                _isShowPopup = true;
              });
            } else if (state == AnimationStatus.reverse) {
              setState(() {
                _isShowPopup = false;
              });
            }
          });
    _slideTopAnimation =
        new Tween(begin: -75.0, end: 0.0).animate(_slideTopAnimationController)
          ..addStatusListener((state) {
            if (!mounted) {
              return;
            }
            if (state == AnimationStatus.forward) {
              setState(() {
                _isHiddenControls = false;
              });
            } else if (state == AnimationStatus.reverse) {
              setState(() {
                _isHiddenControls = true;
              });
            }
          });
    _slideBottomAnimation = new Tween(begin: -30.0, end: 0.0)
        .animate(_slideBottomAnimationController)
          ..addStatusListener((state) {
            if (!mounted) {
              return;
            }
            if (state == AnimationStatus.forward) {
              setState(() {
                _isHiddenControls = false;
              });
            } else if (state == AnimationStatus.reverse) {
              setState(() {
                _isHiddenControls = true;
              });
            }
          });
    if (_videoPlayerController != null) {
      _videoPlayerController
        ..addListener(listener)
        ..setVolume(1.0);
    }
    _widgetsBindingObserver = LifecycleEventHandler(cb: _lifecycleEventHandler);
    // 生命周期钩子
    WidgetsBinding.instance.addObserver(_widgetsBindingObserver);
    // 避免内存泄漏
    WidgetsBinding.instance.addPostFrameCallback((callback) {
      _initPlatCode();
    });
    super.initState();
  }

  void _didDispose() {
    if (_widgetsBindingObserver != null) {
      WidgetsBinding.instance.removeObserver(_widgetsBindingObserver);
      _widgetsBindingObserver = null;
    }

    if (_timer != null) {
      _timer.cancel();
      _timer = null;
    }
    if (_animationController != null) {
      _animationController.dispose();
      _animationController = null;
    }
    if (_slideTopAnimationController != null) {
      _slideTopAnimationController.dispose();
      _slideTopAnimationController = null;
    }
    if (_slideBottomAnimationController != null) {
      _slideBottomAnimationController.dispose();
      _slideBottomAnimationController = null;
    }
    if (_videoPlayerController != null && !_isFullScreenMode) {
      _videoPlayerController.pause();
      _videoPlayerController.removeListener(listener);
      _videoPlayerController.dispose();
      _videoPlayerController = null;
      unSetNormallyOn();
    }
  }

  void _showOverlay() {
    DdOverlay.show(
      context,
      Scaffold(
        backgroundColor: Theme.of(context).primaryColor,
        body: _buildFixedVideoView(),
      ),
    );
  }

  Widget _buildFullScreenVideoView() {
    return VideoView(
      title: widget.title,
      controller: _videoPlayerController,
      isFullScreenMode: true,
      thumbnail: _thumbnail,
      listener: _listener,
      enableDLNA: _enableDLNA,
      enablePip: _enablePip,
      enableFixed: false,
      speed: widget.speed,
    );
  }

  Widget _buildFixedVideoView() {
    return FixedVideo(
      videoPlayerController: _videoPlayerController,
      videoTitle: "",
        listener: _listener,
      fixedVideoCloseTaped: (state) {
        DdOverlay.hide();
        _didDispose();
      },
      fixedVideoPlayerTaped: (state) {
        print("暂未实现");
      }, pageState: null,
    );
  }

  void listener() {
    if (!mounted) {
      return;
    }
    if (_listener != null) {
      _listener(_videoPlayerController);
    }
    try {
      setState(() {});
    } catch (e) {
      //
    }
  }

  @override
  void didUpdateWidget(VideoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller != null) {
        oldWidget.controller.removeListener(listener);
      }
      widget.controller.addListener(listener);
    }
  }

  @override
  void dispose() {
    if (!_enableFixed) {
      _didDispose();
    }
    super.dispose();
  }

  void _initPlatCode() {
    _initDlna();
    _initVB();
  }

  void _initVB() async {
    int cv = await DdPlayerVolume.currentVolume;
    int mv = await DdPlayerVolume.maxVolume;
    int cb = await DdPlayerScreen.currentBrightness;
    if (!mounted) {
      return;
    }
    setState(() {
      _currentVolume = cv;
      _maxVolume = mv;
      _currentBrightness = cb;
    });
  }

  Widget _buildDlna() {
    if (_devices.length == 0) {
      return Container(
        padding: EdgeInsets.all(20.0),
        child: Center(
          child: Text(
            "暂无可用设备,请确保两者在同一wifi下.",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
    }
    return ListView(
        children: []..addAll(
            _devices.map<Widget>((item) {
              return ListTile(
                title: Text(
                  item["name"],
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.0,
                  ),
                ),
                subtitle: Text(
                  item["ip"],
                  style: TextStyle(
                    color: Colors.black38,
                    fontSize: 10.0,
                  ),
                ),
                onTap: () async {
//                Toasty.success("已发送到投屏设备");
                  _hidePopup();
                  FlutterDlna.play(
                      item["uuid"], _videoPlayerController.dataSource);
                },
              );
            }),
          ));
  }

  void _initDlna() async {
    if (!_enableDLNA) {
      return;
    }
    FlutterDlna.subscribe((List<dynamic> data) {
      if (!mounted) {
        return;
      }
      setState(() {
        _devices = data;
      });
    });
    FlutterDlna.search();
    List<dynamic> data = await FlutterDlna.devices;
    if (!mounted) {
      return;
    }
    setState(() {
      _devices = data;
    });
//    print(devices);
  }

  Widget _buildThumbnail(Widget thumbnailBg, Widget child) {
//    var height = _isFullScreenMode
//        ? MediaQuery.of(context).size.height
//        : MediaQuery.of(context).size.height / 3;
//    var width = MediaQuery.of(context).size.width;
    return Container(
      color: Colors.black,
//      height: height,
//      width: width,
      child: Stack(
        children: <Widget>[
          Positioned.fill(child: thumbnailBg),
          Positioned.fill(
            child: Center(
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMask({String errMsg = "", bool isLoading = false}) {
    Widget thumbnailBg = _thumbnail;
    if (thumbnailBg == null) {
      thumbnailBg = _emptyWidget();
    }
    Widget child = _emptyWidget();
    if (isLoading) {
      child = cpi;
    } else if (errMsg != "") {
      child = Text(
        errMsg,
        style: TextStyle(color: Colors.white),
      );
    }
    return _buildThumbnail(thumbnailBg, child);
  }

  Widget _buildCenterContainer(Widget child) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.all(
            Radius.circular(5.0),
          ),
        ),
        padding: EdgeInsets.fromLTRB(10.0, 5.0, 10.0, 5.0),
        child: child,
      ),
    );
  }

  Widget _buildVideoCenter() {
    if (_showPositionInfo) {
      return _buildCenterContainer(
          Text("进度: " + _formatPrePosition + " / " + _formatDuration,
              style: TextStyle(
                color: Colors.white,
              )));
    }
    if (_showVolumeInfo) {
      return _buildCenterContainer(Text("音量: " + _volumePercentage + "%",
          style: TextStyle(
            color: Colors.white,
          )));
    }
    if (_showBrightnessInfo) {
      return _buildCenterContainer(Text(
        "亮度: " + _currentBrightness.abs().toString() + "%",
        style: TextStyle(
          color: Colors.white,
        ),
      ));
    }

    return _emptyWidget();
  }

  Widget _buildVideo() {
    return Container(
      color: Colors.black,
      height: _isFullScreenMode
          ? MediaQuery.of(context).size.height
          : double.infinity,
      width: MediaQuery.of(context).size.width,
      child: Stack(
        children: <Widget>[
          // 播放区域
          Positioned(
              top: 0.0,
              left: 0.0,
              right: 0.0,
              bottom: 0.0,
              child: Stack(
                children: <Widget>[
                  Positioned(
                    top: 0.0,
                    left: 0.0,
                    right: 0.0,
                    bottom: 0.0,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: _videoPlayerController.value.aspectRatio,
                        child: _videoPlayerController == null
                            ? Container(
                                color: Colors.black,
                              )
                            : VideoPlayer(_videoPlayerController),
                      ),
                    ),
                  ),
                  // 加载条
                  Positioned(
                    top: 0.0,
                    left: 0.0,
                    right: 0.0,
                    bottom: 0.0,
                    child: _videoPlayerController != null
                        ? Opacity(
                            opacity: _videoPlayerController.value.isBuffering
                                ? 1.0
                                : 0.0,
                            child: Center(
                              child: cpi,
                            ),
                          )
                        : _emptyWidget(),
                  )
                ],
              )),
          // 加载状态/控制显示
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildVideoCenter(),
          ),
          // 手势区域
          Positioned(
            top: 0.0,
            left: 0.0,
            right: 0.0,
            bottom: 0.0,
            child: GestureDetector(
              onTap: () {
                _switchControls();
              },
              onDoubleTap: () {
                // 双加切换播放/暂停
                _switchPlayState();
              },
              // 垂直
              onVerticalDragDown: (DragDownDetails details) {
                if (_isLocked) {
                  return;
                }
                _panStartX = details.globalPosition.dx;
                _panStartY = details.globalPosition.dy;
              },
              onVerticalDragUpdate: _controlVB,
              onVerticalDragEnd: (_) {
                if (_isLocked) {
                  return;
                }
                _hideAllInfo();
              },
//                onVerticalDragCancel: () => _hideAllInfo(),
              // 水平
              onHorizontalDragDown: (DragDownDetails details) {
                if (_isLocked) {
                  return;
                }
                _preLoadPosition =
                    _videoPlayerController.value.position.inSeconds;
                _panStartX = details.globalPosition.dx;
              },
              onHorizontalDragUpdate: _controlPosition,
              onHorizontalDragEnd: (_) {
                if (_isLocked) {
                  return;
                }
                _seekTo(_preLoadPosition.toDouble());
                _hideAllInfo();
              },
//                onHorizontalDragCancel: () {
//                  _seekTo(_preLoadPosition.toDouble());
//                  _hideAllInfo();
//                },
            ),
          ),
          // 锁定按钮
          !_isFullScreenMode || _isHiddenControls
              ? _emptyWidget()
              : Positioned(
                  top: 0,
                  left: 0,
                  bottom: 0,
                  child: Container(
                    width: 40.0,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        IconButton(
                          icon: Icon(
                            _isLocked ? Icons.lock : Icons.lock_open,
                            size: 24,
                            color: Colors.white,
                          ),
                          onPressed: () {
//                              _hideControls();
                            if (!_isLocked) {
                              _hideControls();
                            } else {
                              _showControls();
                            }
                            setState(() {
                              _isLocked = !_isLocked;
                            });
                          },
                        )
                      ],
                    ),
                  ),
                ),
          // 上部控制条
          SlideTransitionBar(
            child: _buildTopControls(),
            animation: _slideTopAnimation,
          ),
          // 下部控制条
          SlideTransitionBar(
            child: _buildBottomControls(),
            animation: _slideBottomAnimation,
            isBottom: true,
          ),
          PlayerPopupAnimated(
            animation: _animation,
            width: _popupWidth,
            child: _popupType == PopupType.dlna ? _buildDlna() : _emptyWidget(),
          ),
        ],
      ),
    );
  }

//  Widget _buildVideo() {
////    if (!_isFullScreenMode) {
////      return __buildVideo();
////    }
//    return WillPopScope(
//      child: __buildVideo(),
//      onWillPop: () async {
//        if (!_isFullScreenMode) {
//          if (_enableFixed) {
//            _showOverlay();
//          }
//          return true;
//        }
//        if (!_isLocked) {
//          _exitFullScreen();
//          return false;
//        }
//        return !_isLocked;
//      },
//    );
//  }

  Widget _buildSliderLabel(String label) {
    return Text(label,
        style: TextStyle(
            color: Colors.white, fontSize: 10.0, fontWeight: FontWeight.bold));
  }

  Widget _buildControlIconButton(IconData icon, Function onTap,
      [double size = 24]) {
    return GestureDetector(
      child: Padding(
        padding: EdgeInsets.only(left: 5.0, right: 5.0),
        child: Icon(
          icon,
          size: size,
          color: Colors.white,
        ),
      ),
      onTap: () => onTap(),
    );
  }

  Widget _buildTopControls() {
    return Container(
      height: 45.0,
      color: Colors.transparent,
      padding: EdgeInsets.only(left: 10.0, right: 10.0),
//      margin: EdgeInsets.only(top: _isFullScreenMode ? 0.0 : 30.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Row(
            children: <Widget>[
              _buildControlIconButton(Icons.chevron_left, _backTouched),
              Padding(
                padding: EdgeInsets.only(left: 5.0, right: 5.0),
                child: Text(
                  "${ widget.title==null ? '未知' : widget.title }",
                  style: TextStyle(color: Colors.white, fontSize: _isFullScreenMode ? 18.0 : 14.0),
                ),
              )
            ],
          ),
          Row(
            children: <Widget>[
              // Text(_enableDLNA.toString(), style: TextStyle(color: Colors.white),),
//              _isFullScreenMode
//                  ? _buildControlIconButton(Icons.speaker_notes, _switchPopup)
//                  : _emptyWidget(),
              _isFullScreenMode
                  ? _buildControlIconButton(Icons.rotate_left, _rotateScreen)
                  : _emptyWidget(),
              _enableDLNA
                  ? _buildControlIconButton(Icons.tv, _enterDlna, 20)
                  : _emptyWidget(),
//              _isFullScreenMode
//                  ? _buildControlIconButton(Icons.tv, _enterDlna, 20)
//                  : _emptyWidget(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      height: 30.0,
      padding: EdgeInsets.only(left: 10.0, right: 10.0),
      decoration: BoxDecoration(
        gradient: new LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white10,
              Colors.white54,
            ]),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          _buildControlIconButton(
              _videoPlayerController.value.isPlaying
                  ? Icons.pause
                  : Icons.play_arrow,
              _switchPlayState),
          Expanded(
              child: Row(
            children: <Widget>[
              // 进度条
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(0.0),
                  child: SliderTheme(
                      data: SliderThemeData(
                        thumbColor: Colors.white,
                        inactiveTickMarkColor: Colors.white,
                        activeTrackColor: Colors.teal,
                      ),
                      child: Slider(
                        value: _position,
                        max: _duration,
                        onChanged: (d) {
                          _seekTo(d);
                        },
                        //activeColor: Colors.grey,
                        //inactiveColor: Colors.white,
                      )
                  ),
                ),
              ),
              _buildSliderLabel(_formatPosition),
              _buildSliderLabel("/"),
              _buildSliderLabel(_formatDuration),
            ],
          )),

          _buildControlIconButton(_isMute ? Icons.volume_off : Icons.volume_up, _muteVoice),

          GestureDetector(child: Padding(
              padding: EdgeInsets.only(left: 5.0, right: 5.0),
              child: new Container(
                width: 30.0,
                child: Text(speeds[speedSelected].key, style: TextStyle(fontSize: _isFullScreenMode ? 18.0 : 15.0, color: Colors.white),),
              ),
              ),
            onTap: (){
              setState(() {
                speedSelected ++;
                if(speedSelected >= speeds.length) {
                  speedSelected = 0;
                }
                _videoPlayerController.setSpeed(speeds[speedSelected].value);
              });
            },
          ),

          !_isFullScreenMode
              ? _buildControlIconButton(Icons.fullscreen, _switchFullMode)
              : _emptyWidget()
        ],
      ),
    );
  }

  Widget _emptyWidget() {
    return Container(
      height: 0.0,
      width: 0.0,
    );
  }

  void _rotateScreen() {
    _startTimer();
    _defaultFullScreenOrientation =
        _defaultFullScreenOrientation == DeviceOrientation.landscapeLeft
            ? DeviceOrientation.landscapeRight
            : DeviceOrientation.landscapeLeft;
    SystemChrome.setPreferredOrientations([_defaultFullScreenOrientation]);
  }

  void _enterDlna() async {
    setState(() {
      _popupType = PopupType.dlna;
    });
    _switchPopup();
  }

  void _enterFullScreen() async {
    SystemChrome.setEnabledSystemUIOverlays([]);
    // 设置横屏
    SystemChrome.setPreferredOrientations([_defaultFullScreenOrientation]);
    await Navigator.of(context).push(_noTransitionPageRoute(
        context: context,
        builder: (BuildContext context, Widget child) {
          return Scaffold(
            body: _buildFullScreenVideoView(),
          );
        }));
    _initDlna();
  }

  void _exitFullScreen() {
    _hidePopup();
    Navigator.of(context).pop();
    // 退出全屏
    SystemChrome.setEnabledSystemUIOverlays(
        [SystemUiOverlay.bottom, SystemUiOverlay.top]);
    // 返回竖屏
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  void _backTouched() {
    if (_isFullScreenMode) {
      _switchFullMode();
      return;
    }
    Navigator.of(context).pop();
  }

  Future _muteVoice() async {
    _isMute = !_isMute;
    int volume = await DdPlayerVolume.currentVolume;
    if(_isMute) {
      while(volume > 0 ) {
        volume = await DdPlayerVolume.decrementVolume();
      }
    } else {
      while(volume < _maxVolume/2) {
        volume = await DdPlayerVolume.incrementVolume();
      }
    }
    setState(() {});
  }

  void _switchFullMode() {
    _startTimer();
    if (_isFullScreenMode) {
      _exitFullScreen();
    } else {
      _enterFullScreen();
    }
  }

  void _startTimer() {
    if (_timer != null) {
      _timer.cancel();
      _timer = null;
    }
    if (_isShowPopup) {
      return;
    }
    _timer = Timer(Duration(milliseconds: 5000), () {
      _hideControls();
    });
  }

  void _switchPopup() {
    if (_isShowPopup) {
      _animationController.reverse();
    } else {
      if (_timer != null) {
        _timer.cancel();
        _timer = null;
      }
      _hideControls();
      _animationController.forward();
    }
  }

  void _hidePopup() {
    if (_isShowPopup) {
      _animationController.reverse();
    }
  }

  void _switchControls() {
    _hidePopup();
    if (_isLocked) {
      setState(() {
        _isHiddenControls = !_isHiddenControls;
      });
      return;
    }
    if (!_isHiddenControls == false) {
      _startTimer();
    }
    if (_isHiddenControls) {
      _showControls();
    } else {
      _hideControls();
    }
  }

  void _showControls() {
    _slideTopAnimationController.forward();
    _slideBottomAnimationController.forward();
  }

  void _hideControls() {
    _slideTopAnimationController.reverse();
    _slideBottomAnimationController.reverse();
  }

  void _switchPlayState() async {
    if (_videoPlayerController == null || _isLocked) {
      return;
    }
    _startTimer();
    if (_videoPlayerController.value.isPlaying) {
      _videoPlayerController.pause();
    } else {
      _videoPlayerController.play();
      _showControls();
    }
  }

  void _seekTo(double seconds) {
    _hidePopup();
    if (_videoPlayerController != null) {
      _startTimer();
      _videoPlayerController.seekTo(Duration(seconds: seconds.toInt()));
      _videoPlayerController.play();
    }
  }

  void _hideAllInfo() {
    setState(() {
      _showVolumeInfo = false;
      _showBrightnessInfo = false;
      _showPositionInfo = false;
    });
  }

  // 控制进度
  void _controlPosition(DragUpdateDetails details) {
    if (_isLocked) {
      return;
    }
    if (details.sourceTimeStamp.inMilliseconds - _lastSourceTimeStamp < 120) {
      return;
    }
    _hideAllInfo();
    _lastSourceTimeStamp = details.sourceTimeStamp.inMilliseconds;
    double lastPanStartX = details.globalPosition.dx - _panStartX;
    _panStartX = details.globalPosition.dx;
    setState(() {
      _showPositionInfo = true;
    });
    if (lastPanStartX < 0) {
      _preLoadPosition -= 5;
    } else {
      _preLoadPosition += 5;
    }
  }

  // 控制音量和亮度
  void _controlVB(DragUpdateDetails details) async {
    if (_isLocked) {
      return;
    }
    if (details.sourceTimeStamp.inMilliseconds - _lastSourceTimeStamp < 120) {
      return;
    }
    _hideAllInfo();
    _lastSourceTimeStamp = details.sourceTimeStamp.inMilliseconds;
    double lastPanStartY = details.globalPosition.dy - _panStartY;
    _panStartY = details.globalPosition.dy;
    int afterVal;
    if (MediaQuery.of(context).size.width / 2 < _panStartX) {
      setState(() {
        _showVolumeInfo = true;
      });
      // 右边 调节音量
      if (lastPanStartY < 0) {
        // 向上
        afterVal = await DdPlayerVolume.incrementVolume();
      } else {
        // 向下
        afterVal = await DdPlayerVolume.decrementVolume();
      }
      setState(() {
        _currentVolume = afterVal;
      });
    } else {
      setState(() {
        _showBrightnessInfo = true;
      });
      if (lastPanStartY < 0) {
        // 向上
        afterVal = await DdPlayerScreen.incrementBrightness();
      } else {
        // 向下
        afterVal = await DdPlayerScreen.decrementBrightness();
      }
      setState(() {
        _currentBrightness = afterVal;
      });
    }
  }

  String _formatTime(double sec) {
    Duration d = Duration(seconds: sec.toInt());
    final ms = d.inMilliseconds;
    int seconds = ms ~/ 1000;
    final int hours = seconds ~/ 3600;
    seconds = seconds % 3600;
    var minutes = seconds ~/ 60;
    seconds = seconds % 60;

    final hoursString = hours >= 10 ? '$hours' : hours == 0 ? '00' : '0$hours';

    final minutesString =
        minutes >= 10 ? '$minutes' : minutes == 0 ? '00' : '0$minutes';

    final secondsString =
        seconds >= 10 ? '$seconds' : seconds == 0 ? '00' : '0$seconds';

    final formattedTime =
        '${hoursString == '00' ? '' : hoursString + ':'}$minutesString:$secondsString';

    return formattedTime;
  }

  void _lifecycleEventHandler(AppLifecycleState state) {
    if (!_enablePip) {
      return;
    }
    print("========$state=======");

    if (state == AppLifecycleState.inactive) {
      if (!_isBackgroundMode) {
        _enterPip();
        _isBackgroundMode = true;
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_isBackgroundMode) {
        if (!_isFullScreenMode && mounted) {
          Navigator.of(context).pop();
        }
        _isBackgroundMode = false;
      }
    }
  }

  void _enterPip() {
    if (!_isFullScreenMode) {
      Navigator.of(context).push(_noTransitionPageRoute(
          context: context,
          builder: (BuildContext context, Widget child) {
            return Scaffold(
              backgroundColor: Theme.of(context).primaryColor,
              body: _buildFullScreenVideoView(),
            );
          }));
    }
    // TODO 自动调整显示比例 当播放器初始化成功后
    DdPlayerScreen.enterPip();
  }

  PageRouteBuilder _noTransitionPageRoute(
      {@required BuildContext context, @required TransitionBuilder builder}) {
    return PageRouteBuilder(
      settings: RouteSettings(isInitialRoute: false),
      pageBuilder: (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
      ) {
        return AnimatedBuilder(
          animation: animation,
          builder: builder,
        );
      },
    );
  }
}
