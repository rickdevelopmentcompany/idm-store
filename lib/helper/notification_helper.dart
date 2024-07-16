import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sixam_mart_store/features/auth/controllers/auth_controller.dart';
import 'package:sixam_mart_store/features/chat/controllers/chat_controller.dart';
import 'package:sixam_mart_store/features/notification/controllers/notification_controller.dart';
import 'package:sixam_mart_store/features/order/controllers/order_controller.dart';
import 'package:sixam_mart_store/features/notification/domain/models/notification_body_model.dart';
import 'package:sixam_mart_store/helper/route_helper.dart';
import 'package:sixam_mart_store/util/app_constants.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:sixam_mart_store/features/dashboard/widgets/new_request_dialog_widget.dart';

class NotificationHelper {

  static Future<void> initialize(FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin) async {
    var androidInitialize = const AndroidInitializationSettings('notification_icon');
    var iOSInitialize = const DarwinInitializationSettings();
    var initializationsSettings = InitializationSettings(android: androidInitialize, iOS: iOSInitialize);
    flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()!.requestNotificationsPermission();
    flutterLocalNotificationsPlugin.initialize(initializationsSettings, onDidReceiveNotificationResponse: (NotificationResponse load) async{
      try{
        if(load.payload!.isNotEmpty){

          NotificationBody payload = NotificationBody.fromJson(jsonDecode(load.payload!));

          if(payload.notificationType == NotificationTypeModel.order){
            Get.offAllNamed(RouteHelper.getOrderDetailsRoute(payload.orderId, fromNotification: true));
          }else if(payload.notificationType == NotificationTypeModel.general){
            Get.offAllNamed(RouteHelper.getNotificationRoute(fromNotification: true));
          } else{
            Get.offAllNamed(RouteHelper.getChatRoute(notificationBody: payload, conversationId: payload.conversationId, fromNotification: true
            ));
          }

        }
      }catch(_){}
      return;
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {

      debugPrint("onMessage message type:${message.data['type']}");
      debugPrint("onMessage message :${message.data}");

      if(message.data['type'] == 'message' && Get.currentRoute.startsWith(RouteHelper.chatScreen)) {
        if(Get.find<AuthController>().isLoggedIn()) {
          Get.find<ChatController>().getConversationList(1);
          if(Get.find<ChatController>().messageModel!.conversation!.id.toString() == message.data['conversation_id'].toString()) {
            Get.find<ChatController>().getMessages(
              1, NotificationBody(
              notificationType: NotificationTypeModel.message,
              customerId: message.data['sender_type'] == AppConstants.user ? 0 : null,
              deliveryManId: message.data['sender_type'] == AppConstants.deliveryMan ? 0 : null,
            ),
              null, int.parse(message.data['conversation_id'].toString()),
            );
          }else {
            NotificationHelper.showNotification(message, flutterLocalNotificationsPlugin);
          }
        }
      }else if(message.data['type'] == 'message' && Get.currentRoute.startsWith(RouteHelper.conversationListScreen)) {
        if(Get.find<AuthController>().isLoggedIn()) {
          Get.find<ChatController>().getConversationList(1);
        }
        NotificationHelper.showNotification(message, flutterLocalNotificationsPlugin);
      }else {
        NotificationHelper.showNotification(message, flutterLocalNotificationsPlugin);

        if (message.data['type'] == 'new_order' || message.data['title'] == 'New order placed') {
          Get.find<OrderController>().getPaginatedOrders(1, true);
          Get.find<OrderController>().getCurrentOrders();

          Get.dialog(NewRequestDialogWidget(orderId: int.parse(message.data['order_id'])));
        }

        Get.find<NotificationController>().getNotificationList();

      }

    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {

      debugPrint("onOpenApp message type:${message.data['type']}");
      debugPrint("onOpenApp message :${message.data}");

      try{
        NotificationBody notificationBody = convertNotification(message.data);

        if(notificationBody.notificationType == NotificationTypeModel.order){
          Get.offAllNamed(RouteHelper.getOrderDetailsRoute(int.parse(message.data['order_id']), fromNotification: true));
        } else if(notificationBody.notificationType == NotificationTypeModel.general){
          Get.offAllNamed(RouteHelper.getNotificationRoute(fromNotification: true));
        } else{
          Get.offAllNamed(RouteHelper.getChatRoute(notificationBody: notificationBody, conversationId: notificationBody.conversationId, fromNotification: true));
        }
      }catch (_){}
    });
  }

  static Future<void> showNotification(RemoteMessage message, FlutterLocalNotificationsPlugin fln) async {
    if(!GetPlatform.isIOS) {
      String? title;
      String? body;
      String? image;
      NotificationBody notificationBody = convertNotification(message.data);

      title = message.data['title'];
      body = message.data['body'];
      image = (message.data['image'] != null && message.data['image'].isNotEmpty) ? message.data['image'].startsWith('http') ? message.data['image']
        : '${AppConstants.baseUrl}/storage/app/public/notification/${message.data['image']}' : null;

      if(image != null && image.isNotEmpty) {
        try{
          await showBigPictureNotificationHiddenLargeIcon(title, body, notificationBody, image, fln);
        }catch(e) {
          await showBigTextNotification(title, body!, notificationBody, fln);
        }
      }else {
        await showBigTextNotification(title, body!, notificationBody, fln);
      }
    }
  }

  static Future<void> showTextNotification(String title, String body, NotificationBody notificationBody, FlutterLocalNotificationsPlugin fln) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      '6ammart', '6ammart', playSound: true,
      importance: Importance.max, priority: Priority.max, sound: RawResourceAndroidNotificationSound('notification'),
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await fln.show(0, title, body, platformChannelSpecifics, payload: jsonEncode(notificationBody.toJson()));
  }

  static Future<void> showBigTextNotification(String? title, String body, NotificationBody notificationBody, FlutterLocalNotificationsPlugin fln) async {
    BigTextStyleInformation bigTextStyleInformation = BigTextStyleInformation(
      body, htmlFormatBigText: true,
      contentTitle: title, htmlFormatContentTitle: true,
    );
    AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      '6ammart', '6ammart', importance: Importance.max,
      styleInformation: bigTextStyleInformation, priority: Priority.max, playSound: true,
      sound: const RawResourceAndroidNotificationSound('notification'),
    );
    NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await fln.show(0, title, body, platformChannelSpecifics, payload: jsonEncode(notificationBody.toJson()));
  }

  static Future<void> showBigPictureNotificationHiddenLargeIcon(String? title, String? body, NotificationBody notificationBody, String image, FlutterLocalNotificationsPlugin fln) async {
    final String largeIconPath = await _downloadAndSaveFile(image, 'largeIcon');
    final String bigPicturePath = await _downloadAndSaveFile(image, 'bigPicture');
    final BigPictureStyleInformation bigPictureStyleInformation = BigPictureStyleInformation(
      FilePathAndroidBitmap(bigPicturePath), hideExpandedLargeIcon: true,
      contentTitle: title, htmlFormatContentTitle: true,
      summaryText: body, htmlFormatSummaryText: true,
    );
    final AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      '6ammart', '6ammart',
      largeIcon: FilePathAndroidBitmap(largeIconPath), priority: Priority.max, playSound: true,
      styleInformation: bigPictureStyleInformation, importance: Importance.max,
      sound: const RawResourceAndroidNotificationSound('notification'),
    );
    final NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await fln.show(0, title, body, platformChannelSpecifics, payload: jsonEncode(notificationBody.toJson()));
  }

  static Future<String> _downloadAndSaveFile(String url, String fileName) async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final String filePath = '${directory.path}/$fileName';
    final http.Response response = await http.get(Uri.parse(url));
    final File file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);
    return filePath;
  }

  static NotificationBody convertNotification(Map<String, dynamic> data){
    if(data['type'] == 'general'){
      return NotificationBody(notificationType: NotificationTypeModel.general) ;
    }
    else if(data['type'] == 'new_order' || data['type'] == 'New order placed' || data['type'] == 'order_status'){
      return NotificationBody(orderId: int.parse(data['order_id']), notificationType: NotificationTypeModel.order);
    }
    else{
      return NotificationBody(
        orderId: (data['order_id'] != null && data['order_id'].isNotEmpty) ? int.parse(data['order_id']) : null,
        conversationId: (data['conversation_id'] != null && data['conversation_id'].isNotEmpty) ? int.parse(data['conversation_id']) : null,
        notificationType: NotificationTypeModel.message,
        type: data['sender_type'] == AppConstants.deliveryMan ? AppConstants.deliveryMan : AppConstants.customer,
      );
    }
  }

}

Future<dynamic> myBackgroundMessageHandler(RemoteMessage message) async {
  debugPrint("onBackground: ${message.data}");
}