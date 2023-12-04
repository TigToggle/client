import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;

import 'package:fluffychat/pangea/config/environment.dart';
import 'package:fluffychat/pangea/controllers/subscription_controller.dart';
import 'package:fluffychat/pangea/utils/error_handler.dart';
import 'package:fluffychat/pangea/utils/subscription_app_id.dart';
import '../network/urls.dart';

class SubscriptionRepo {
  static final Map<String, String> requestHeaders = {
    'Content-type': 'application/json',
    'Accept': 'application/json',
    'Authorization': 'Bearer ${Environment.rcKey}',
  };

  static Future<SubscriptionAppIds?> getAppIds() async {
    try {
      final http.Response res = await http.get(
        Uri.parse(PApiUrls.rcApps),
        headers: SubscriptionRepo.requestHeaders,
      );
      final json = jsonDecode(res.body);
      return SubscriptionAppIds.fromJson(json);
    } catch (err) {
      ErrorHandler.logError(
        m: "Failed to fetch app information for revenuecat API",
        s: StackTrace.current,
      );
      return null;
    }
  }

  static Future<List<SubscriptionDetails>?> getAllProducts() async {
    try {
      final http.Response res = await http.get(
        Uri.parse(PApiUrls.rcProducts),
        headers: SubscriptionRepo.requestHeaders,
      );
      final Map<String, dynamic> json = jsonDecode(res.body);
      final RCProductsResponseModel resp =
          RCProductsResponseModel.fromJson(json);
      return resp.allProducts;
    } catch (err) {
      ErrorHandler.logError(
        m: "Failed to fetch entitlement information for revenuecat API",
        s: StackTrace.current,
      );
      return null;
    }
  }

  static Future<RCSubscriptionResponseModel> getCurrentSubscriptionInfo(
    String? userId,
    List<SubscriptionDetails>? allProducts,
  ) async {
    final Map<String, String> stripeHeaders = {
      'Content-type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer ${Environment.rcStripeKey}',
    };
    final String url = "${PApiUrls.rcSubscribers}/$userId";
    final http.Response res = await http.get(
      Uri.parse(url),
      headers: stripeHeaders,
    );
    final Map<String, dynamic> json = jsonDecode(res.body);
    final RCSubscriptionResponseModel resp =
        RCSubscriptionResponseModel.fromJson(
      json,
      allProducts,
    );
    return resp;
  }
}

class RCProductsResponseModel {
  List<SubscriptionDetails> allProducts;

  RCProductsResponseModel({
    required this.allProducts,
  });

  factory RCProductsResponseModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final List<dynamic> offerings = json["items"] as List<dynamic>;
    final offering = offerings.firstWhereOrNull(
      Environment.isStaging
          ? (offering) => !(offering['is_current'] as bool)
          : (offering) => offering['is_current'] as bool,
    );
    final Map<String, dynamic> metadata = offering['metadata'];

    final List<SubscriptionDetails> allProducts = [];
    for (final packageDetails in offering['packages']['items']) {
      final String packageId = packageDetails['id'];
      final List<SubscriptionDetails> products =
          RCProductsResponseModel.productsFromPackageDetails(
        packageDetails,
        packageId,
        metadata,
      );
      allProducts.addAll(products);
    }

    return RCProductsResponseModel(allProducts: allProducts);
  }

  static List<SubscriptionDetails> productsFromPackageDetails(
    Map<String, dynamic> packageDetails,
    String packageId,
    Map<String, dynamic> metadata,
  ) {
    return packageDetails['products']['items']
        .map((productDetails) => SubscriptionDetails(
              price: double.parse(metadata['$packageId.price']),
              duration: metadata['$packageId.duration'],
              id: productDetails['product']['store_identifier'],
              appId: productDetails['product']['app_id'],
            ),)
        .toList()
        .cast<SubscriptionDetails>();
  }
}

class RCSubscriptionResponseModel {
  String? currentSubscriptionId;
  SubscriptionDetails? currentSubscription;
  DateTime? expirationDate;
  List<String>? allEntitlements;

  RCSubscriptionResponseModel({
    this.currentSubscriptionId,
    this.currentSubscription,
    this.allEntitlements,
    this.expirationDate,
  });

  factory RCSubscriptionResponseModel.fromJson(
    Map<String, dynamic> json,
    List<SubscriptionDetails>? allProducts,
  ) {
    final List<String> activeEntitlements =
        RCSubscriptionResponseModel.getActiveEntitlements(json);

    final List<String> allEntitlements =
        RCSubscriptionResponseModel.getAllEntitlements(json);

    if (activeEntitlements.length > 1) {
      debugPrint(
        "User has more than one active entitlement. This shouldn't happen",
      );
    }
    if (activeEntitlements.isEmpty) {
      debugPrint("User has no active entitlements");
      return RCSubscriptionResponseModel();
    }

    final String currentSubscriptionId = activeEntitlements[0];

    final Map<String, dynamic> currentSubscriptionMetadata =
        json['subscriber']['subscriptions'][currentSubscriptionId];

    final DateTime expirationDate = DateTime.parse(
      currentSubscriptionMetadata['expires_date'],
    );

    final String currentSubscriptionPeriodType =
        currentSubscriptionMetadata['period_type'] ?? "";

    final SubscriptionDetails? currentSubscription =
        allProducts?.firstWhereOrNull(
      (SubscriptionDetails sub) =>
          sub.id.contains(currentSubscriptionId) ||
          currentSubscriptionId.contains(sub.id),
    );

    if (currentSubscriptionPeriodType == "trial") {
      currentSubscription?.makeTrial();
    }

    return RCSubscriptionResponseModel(
      currentSubscription: currentSubscription,
      currentSubscriptionId: currentSubscriptionId,
      expirationDate: expirationDate,
      allEntitlements: activeEntitlements,
    );
  }

  static List<String> getActiveEntitlements(Map<String, dynamic> json) {
    return json['subscriber']['entitlements']
        .entries
        .where(
          (MapEntry<String, dynamic> entitlement) => DateTime.parse(
            entitlement.value['expires_date'],
          ).isAfter(DateTime.now()),
        )
        .map(
          (MapEntry<String, dynamic> entitlement) =>
              entitlement.value['product_identifier'],
        )
        .cast<String>()
        .toList();
  }

  static List<String> getAllEntitlements(Map<String, dynamic> json) {
    return json['subscriber']['entitlements']
        .entries
        .map(
          (MapEntry<String, dynamic> entitlement) =>
              entitlement.value['product_identifier'],
        )
        .cast<String>()
        .toList();
  }
}
