import '../models/order_model.dart';
import '../../theme/app_theme.dart';
import 'package:flutter/material.dart';

class OrderStatusResolver {
  static String getDisplayStatus(OrderModel order) {
    if (order.quoteStatus == QuoteStatus.Pending) {
      return "Pending Quote";
    }
    if (order.quoteStatus == QuoteStatus.Rejected) {
      return "Quote Rejected";
    }

    switch (order.fulfillmentMode) {
      case 'deployment':
        return _getDeploymentStatus(order.status);
      case 'bulky':
        return _getBulkyStatus(order.status);
      case 'logistics':
      default:
        return _getLogisticsStatus(order.status);
    }
  }

  static String _getLogisticsStatus(OrderStatus status) {
    switch (status) {
      case OrderStatus.New: return "Order Placed";
      case OrderStatus.InProgress: return "Processing";
      case OrderStatus.Ready: return "Ready for Delivery";
      case OrderStatus.Completed: return "Delivered";
      case OrderStatus.Cancelled: return "Cancelled";
      case OrderStatus.Refunded: return "Refunded";
      case OrderStatus.PendingUserConfirmation: return "Awaiting Action";
      case OrderStatus.Inspecting: return "Inspecting";
    }
  }

  static String _getDeploymentStatus(OrderStatus status) {
    switch (status) {
      case OrderStatus.New: return "Booking Received";
      case OrderStatus.InProgress: return "Crew Assigned";
      case OrderStatus.Ready: return "Team Scheduled";
      case OrderStatus.Completed: return "Service Completed";
      case OrderStatus.Cancelled: return "Cancelled";
      case OrderStatus.Refunded: return "Refunded";
      case OrderStatus.PendingUserConfirmation: return "Price Adjustment";
      case OrderStatus.Inspecting: return "Personnel En-Route";
    }
  }

  static String _getBulkyStatus(OrderStatus status) {
    switch (status) {
      case OrderStatus.New: return "Specialist Assigned";
      case OrderStatus.InProgress: return "In Factory";
      case OrderStatus.Ready: return "Ready for Pickup";
      case OrderStatus.Completed: return "Service Finalized";
      case OrderStatus.Cancelled: return "Cancelled";
      case OrderStatus.Refunded: return "Refunded";
      case OrderStatus.PendingUserConfirmation: return "Weight Verified";
      case OrderStatus.Inspecting: return "Inspecting";
    }
  }

  static Color getStatusColor(OrderModel order) {
    if (order.quoteStatus == QuoteStatus.Pending) return Colors.orangeAccent;
    if (order.quoteStatus == QuoteStatus.Rejected) return Colors.redAccent;

    switch (order.status) {
      case OrderStatus.New: return Colors.blueAccent;
      case OrderStatus.InProgress: return Colors.amber;
      case OrderStatus.Ready: return AppTheme.primaryColor;
      case OrderStatus.Completed: return Colors.green;
      case OrderStatus.Cancelled: return Colors.grey;
      case OrderStatus.Refunded: return Colors.red;
      case OrderStatus.PendingUserConfirmation: return Colors.purpleAccent;
      case OrderStatus.Inspecting: return Colors.indigoAccent;
    }
  }
}
