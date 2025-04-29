import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_route.dart';

class RouteStorageService {
  static const String _savedRoutesKey = 'saved_routes';
  static const String _historyRoutesKey = 'history_routes';
  
  Future<List<SavedRoute>> getSavedRoutes() async {
    final prefs = await SharedPreferences.getInstance();
    final routesJson = prefs.getStringList(_savedRoutesKey) ?? [];
    return routesJson.map((json) => SavedRoute.fromJson(jsonDecode(json))).toList();
  }

  Future<List<SavedRoute>> getHistoryRoutes() async {
    final prefs = await SharedPreferences.getInstance();
    final routesJson = prefs.getStringList(_historyRoutesKey) ?? [];
    return routesJson.map((json) => SavedRoute.fromJson(jsonDecode(json))).toList();
  }

  Future<void> saveRoute(SavedRoute route) async {
    final prefs = await SharedPreferences.getInstance();
    final routes = await getSavedRoutes();
    routes.add(route);
    final routesJson = routes.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList(_savedRoutesKey, routesJson);
  }

  Future<void> addToHistory(SavedRoute route) async {
    final prefs = await SharedPreferences.getInstance();
    final routes = await getHistoryRoutes();
    // 限制历史记录数量为最近20条
    if (routes.length >= 20) {
      routes.removeAt(0);
    }
    routes.add(route);
    final routesJson = routes.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList(_historyRoutesKey, routesJson);
  }

  Future<void> deleteRoute(String routeId) async {
    final prefs = await SharedPreferences.getInstance();
    final routes = await getSavedRoutes();
    routes.removeWhere((route) => route.id == routeId);
    final routesJson = routes.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList(_savedRoutesKey, routesJson);
  }

  Future<void> deleteHistoryRoute(String routeId) async {
    final prefs = await SharedPreferences.getInstance();
    final routes = await getHistoryRoutes();
    routes.removeWhere((route) => route.id == routeId);
    final routesJson = routes.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList(_historyRoutesKey, routesJson);
  }
} 