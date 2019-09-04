import 'package:dd_player/defs.dart';
import 'package:dd_player/widgets/video_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:video_player/video_player.dart';


class DdPlayer extends StatefulWidget {
  String title;
  String url;
  Widget thumbnail;
  Function listener;
  VideoPlayerController videoPlayerController;
  bool enableDLNA;
  bool enablePip;
  bool enableFixed;
  double speed;

  DdPlayer({
    Key key,
    @required this.url,
    this.title,
    this.thumbnail,
    this.listener,
    this.enableDLNA = false,
    this.enablePip = false,
    this.videoPlayerController,
    this.enableFixed = false,
    this.speed = 1.0,
  }) : super(key: key);

  @override
  _DdPlayer createState() => _DdPlayer();
}

class _DdPlayer extends State<DdPlayer> {
  VideoPlayerController _videoPlayerController;
  VideoPlayerController get videoPlayerController => widget.videoPlayerController;

  Widget build(BuildContext context) {
    return VideoView(
      title: widget.title,
      controller: videoPlayerController != null ? videoPlayerController : _videoPlayerController,
      thumbnail: widget.thumbnail,
      listener: widget.listener,
      enableDLNA: widget.enableDLNA,
      enablePip: widget.enablePip,
      enableFixed: widget.enableFixed,
      speed: widget.speed,
    );
  }

  void _buildPlayer() {
    if (videoPlayerController != null) {
      videoPlayerController..play();
      return;
    }
    if (widget.url == "") {
      return;
    }

    if (_videoPlayerController != null) {
      _videoPlayerController.pause();
      _videoPlayerController.dispose();
    }
    _videoPlayerController = VideoPlayerController.network(widget.url)
      ..initialize().then((_) {
        setNormallyOn();
        _videoPlayerController.play().then((_){
          _videoPlayerController.setSpeed(widget.speed);
        });
      });
  }

  void initState() {
    _buildPlayer();

    super.initState();
  }

  @override
  void didUpdateWidget(DdPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _buildPlayer();
    }
  }

//  @override
//  void dispose() {
//    if (!widget.enableFixed && _videoPlayerController != null) {
//      unSetNormallyOn();
//      _videoPlayerController.dispose();
//      _videoPlayerController = null;
//    }
//    super.dispose();
//  }
}
