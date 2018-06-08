import 'dart:async';

import 'package:flutter/services.dart';
import 'package:simple_auth/simple_auth.dart' as simpleAuth;

class SimpleAuthFlutter {
  static const MethodChannel _channel =
      const MethodChannel('simple_auth_flutter/showAuthenticator');
  static const EventChannel _eventChannel =
      const EventChannel('simple_auth_flutter/urlChanged');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod("getPlatformVersion");
    return version;
  }

  static Map<String, simpleAuth.WebAuthenticator> authenticators = {};
  static Future showAuthenticator(
      simpleAuth.WebAuthenticator authenticator) async {
    var initialUrl = await authenticator.getInitialUrl();

    authenticators[authenticator.identifier] = authenticator;

    String url = await _channel.invokeMethod("showAuthenticator", {
      "initialUrl": initialUrl.toString(),
      "identifier": authenticator.identifier,
      "title": authenticator.title,
      "allowsCancel": authenticator.allowsCancel.toString(),
      "redirectUrl" : authenticator.redirectUrl,
      "useEmbeddedBrowser": authenticator.useEmbeddedBrowser.toString()
    });
    if (url == "cancel") {
      authenticator.cancel();
      return;
    }
  }

  static void init() {
    simpleAuth.OAuthApi.sharedShowAuthenticator = showAuthenticator;
    onUrlChanged.listen((UrlChange change) {
      var authenticator = authenticators[change.identifier];
      if (change.url == "canceled") {
        authenticator.cancel();
        return;
      }

      else if(change.url == "error"){
        authenticator.onError(change.description);
        return;
      }

      var uri = Uri.tryParse(change.url);
      if (authenticator.checkUrl(uri)){
        _channel.invokeMethod("completed", {"identifier": change.identifier});
      }
      else if(change.foreComplete)
      {
        authenticator.onError("Unable to get an AuthToken from the server");
      }
    });
  }

  static Stream<UrlChange> _onUrlChanged;
  static Stream<UrlChange> get onUrlChanged {
    if (_onUrlChanged == null) {
      _onUrlChanged = _eventChannel.receiveBroadcastStream().map(
          (dynamic event) => new UrlChange(event["identifier"], event["url"], event["forceComplete"],event["description"]));
    }
    return _onUrlChanged;
  }
}

class UrlChange {
  String url;
  String identifier;
  bool foreComplete;
  String description;
  UrlChange(this.identifier, this.url,this.foreComplete, this.description);
}
