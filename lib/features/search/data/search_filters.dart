import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/kv_store.dart';

enum SearchSort { nearest, topRated }

const _filtersKey = 'search.filters';

class SearchFilters {
  final SearchSort sort;
  final bool openNow;
  final bool availableToday;
  final bool verifiedOnly;
  final bool homeServiceOnly;
  final double? maxDistanceKm;
  final double? minPriceBhd;
  final double? maxPriceBhd;

  const SearchFilters({
    this.sort = SearchSort.nearest,
    this.openNow = false,
    this.availableToday = false,
    this.verifiedOnly = false,
    this.homeServiceOnly = false,
    this.maxDistanceKm,
    this.minPriceBhd,
    this.maxPriceBhd,
  });

  SearchFilters copyWith({
    SearchSort? sort,
    bool? openNow,
    bool? availableToday,
    bool? verifiedOnly,
    bool? homeServiceOnly,
    double? maxDistanceKm,
    double? minPriceBhd,
    double? maxPriceBhd,
  }) {
    return SearchFilters(
      sort: sort ?? this.sort,
      openNow: openNow ?? this.openNow,
      availableToday: availableToday ?? this.availableToday,
      verifiedOnly: verifiedOnly ?? this.verifiedOnly,
      homeServiceOnly: homeServiceOnly ?? this.homeServiceOnly,
      maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
      minPriceBhd: minPriceBhd ?? this.minPriceBhd,
      maxPriceBhd: maxPriceBhd ?? this.maxPriceBhd,
    );
  }

  String toRpcSort() {
    return switch (sort) {
      SearchSort.nearest => 'nearest',
      SearchSort.topRated => 'top_rated',
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'sort': sort.name,
      'openNow': openNow,
      'availableToday': availableToday,
      'verifiedOnly': verifiedOnly,
      'homeServiceOnly': homeServiceOnly,
      'maxDistanceKm': maxDistanceKm,
      'minPriceBhd': minPriceBhd,
      'maxPriceBhd': maxPriceBhd,
    };
  }

  static SearchFilters fromJson(Map<String, dynamic> json) {
    final sortRaw = (json['sort'] as String?) ?? SearchSort.nearest.name;
    final parsedSort = SearchSort.values.where((e) => e.name == sortRaw).cast<SearchSort?>().firstWhere((e) => e != null, orElse: () => SearchSort.nearest)!;
    double? _num(dynamic v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
    return SearchFilters(
      sort: parsedSort,
      openNow: (json['openNow'] as bool?) ?? false,
      availableToday: (json['availableToday'] as bool?) ?? false,
      verifiedOnly: (json['verifiedOnly'] as bool?) ?? false,
      homeServiceOnly: (json['homeServiceOnly'] as bool?) ?? false,
      maxDistanceKm: _num(json['maxDistanceKm']),
      minPriceBhd: _num(json['minPriceBhd']),
      maxPriceBhd: _num(json['maxPriceBhd']),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SearchFilters &&
        other.sort == sort &&
        other.openNow == openNow &&
        other.availableToday == availableToday &&
        other.verifiedOnly == verifiedOnly &&
        other.homeServiceOnly == homeServiceOnly &&
        other.maxDistanceKm == maxDistanceKm &&
        other.minPriceBhd == minPriceBhd &&
        other.maxPriceBhd == maxPriceBhd;
  }

  @override
  int get hashCode => Object.hash(sort, openNow, availableToday, verifiedOnly, homeServiceOnly, maxDistanceKm, minPriceBhd, maxPriceBhd);
}

class SearchFiltersController extends Notifier<SearchFilters> {
  @override
  SearchFilters build() {
    _load();
    return const SearchFilters();
  }

  Future<void> _load() async {
    final raw = await ref.read(kvStoreProvider).read(_filtersKey);
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      state = SearchFilters.fromJson(json);
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      await ref.read(kvStoreProvider).write(_filtersKey, jsonEncode(state.toJson()));
    } catch (_) {}
  }

  void setSort(SearchSort sort) {
    state = state.copyWith(sort: sort);
    unawaited(_persist());
  }

  void setOpenNow(bool v) {
    state = state.copyWith(openNow: v);
    unawaited(_persist());
  }

  void setAvailableToday(bool v) {
    state = state.copyWith(availableToday: v);
    unawaited(_persist());
  }

  void setVerifiedOnly(bool v) {
    state = state.copyWith(verifiedOnly: v);
    unawaited(_persist());
  }

  void setHomeServiceOnly(bool v) {
    state = state.copyWith(homeServiceOnly: v);
    unawaited(_persist());
  }

  void setMaxDistanceKm(double? v) {
    state = state.copyWith(maxDistanceKm: v);
    unawaited(_persist());
  }

  void setMinPriceBhd(double? v) {
    state = state.copyWith(minPriceBhd: v);
    unawaited(_persist());
  }

  void setMaxPriceBhd(double? v) {
    state = state.copyWith(maxPriceBhd: v);
    unawaited(_persist());
  }

  void reset() {
    state = const SearchFilters();
    unawaited(_persist());
  }
}

final searchFiltersProvider = NotifierProvider<SearchFiltersController, SearchFilters>(SearchFiltersController.new);
