import 'package:flutter_test/flutter_test.dart';

import 'package:resources_sync/resources_sync.dart';

import 'dart:io';
import 'package:path/path.dart' as path;

import 'package:path_provider/path_provider.dart' as path_provider;

void main() {
  test('Creates a resource sync', () async {
    Directory dirTemp = Directory.current;

    final resourceSync = ResourceSync( 
      dirTarget: Directory( path.join( dirTemp.path, '../temp/resources' ).toString() ),  
      urlSource: 'http://localhost:4000/resources',  
    );

    await resourceSync.sync();
  });
}
