import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import '../models/usb_device.dart';

class UsbIdsRepository {
  static const String _dbName = 'usbids.sqlite';
  Database? _db;

  Future<Database> _getDb() async {
    if (_db != null && _db!.isOpen) return _db!;

    final dbPath = await getDatabasesPath();
    final targetPath = path.join(dbPath, _dbName);

    final exists = await databaseExists(targetPath);
    if (!exists) {
      await Directory(path.dirname(targetPath)).create(recursive: true);
      final data = await rootBundle.load('assets/db/$_dbName');
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(targetPath).writeAsBytes(bytes, flush: true);
    }

    _db = await openDatabase(targetPath, readOnly: true);
    return _db!;
  }

  Future<List<UsbVendor>> searchVendors(String query) async {
    final db = await _getDb();
    final q = query.trim();
    if (q.isEmpty) {
      final results = await db.query(
        'vendors',
        orderBy: 'name ASC',
        limit: 100,
      );
      return results.map((m) => UsbVendor.fromMap(m)).toList(growable: false);
    }

    final vidInt = int.tryParse(q.startsWith('0x') ? q.substring(2) : q, radix: 16);
    if (vidInt != null) {
      final results = await db.query(
        'vendors',
        where: 'vid = ?',
        whereArgs: [vidInt],
      );
      return results.map((m) => UsbVendor.fromMap(m)).toList(growable: false);
    }

    final results = await db.query(
      'vendors',
      where: 'name LIKE ?',
      whereArgs: ['%$q%'],
      orderBy: 'name ASC',
      limit: 100,
    );
    return results.map((m) => UsbVendor.fromMap(m)).toList(growable: false);
  }

  Future<List<UsbProduct>> searchProducts(String query, {int? vendorId}) async {
    final db = await _getDb();
    final q = query.trim();

    if (vendorId != null) {
      if (q.isEmpty) {
        final results = await db.rawQuery('''
          SELECT p.vid, p.pid, p.name, v.name as vendorName
          FROM products p
          LEFT JOIN vendors v ON p.vid = v.vid
          WHERE p.vid = ?
          ORDER BY p.name ASC
          LIMIT 100
        ''', [vendorId]);
        return results.map((m) => UsbProduct.fromMap(m)).toList(growable: false);
      }

      final pidInt = int.tryParse(q.startsWith('0x') ? q.substring(2) : q, radix: 16);
      if (pidInt != null) {
        final results = await db.rawQuery('''
          SELECT p.vid, p.pid, p.name, v.name as vendorName
          FROM products p
          LEFT JOIN vendors v ON p.vid = v.vid
          WHERE p.vid = ? AND p.pid = ?
        ''', [vendorId, pidInt]);
        return results.map((m) => UsbProduct.fromMap(m)).toList(growable: false);
      }

      final results = await db.rawQuery('''
        SELECT p.vid, p.pid, p.name, v.name as vendorName
        FROM products p
        LEFT JOIN vendors v ON p.vid = v.vid
        WHERE p.vid = ? AND p.name LIKE ?
        ORDER BY p.name ASC
        LIMIT 100
      ''', [vendorId, '%$q%']);
      return results.map((m) => UsbProduct.fromMap(m)).toList(growable: false);
    }

    if (q.isEmpty) {
      final results = await db.rawQuery('''
        SELECT p.vid, p.pid, p.name, v.name as vendorName
        FROM products p
        LEFT JOIN vendors v ON p.vid = v.vid
        ORDER BY p.name ASC
        LIMIT 100
      ''');
      return results.map((m) => UsbProduct.fromMap(m)).toList(growable: false);
    }

    final results = await db.rawQuery('''
      SELECT p.vid, p.pid, p.name, v.name as vendorName
      FROM products p
      LEFT JOIN vendors v ON p.vid = v.vid
      WHERE p.name LIKE ? OR v.name LIKE ?
      ORDER BY p.name ASC
      LIMIT 100
    ''', ['%$q%', '%$q%']);
    return results.map((m) => UsbProduct.fromMap(m)).toList(growable: false);
  }

  Future<UsbVendor?> getVendor(int vid) async {
    final db = await _getDb();
    final results = await db.query(
      'vendors',
      where: 'vid = ?',
      whereArgs: [vid],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return UsbVendor.fromMap(results.first);
  }

  Future<UsbProduct?> getProduct(int vid, int pid) async {
    final db = await _getDb();
    final results = await db.rawQuery('''
      SELECT p.vid, p.pid, p.name, v.name as vendorName
      FROM products p
      LEFT JOIN vendors v ON p.vid = v.vid
      WHERE p.vid = ? AND p.pid = ?
      LIMIT 1
    ''', [vid, pid]);
    if (results.isEmpty) return null;
    return UsbProduct.fromMap(results.first);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
