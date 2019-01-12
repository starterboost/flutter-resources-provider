import 'package:flutter_test/flutter_test.dart';

import 'package:resources_sync/resources_provider.dart';

import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;

import 'package:path_provider/path_provider.dart' as path_provider;

void main() {
  test('Creates a resource sync', () async {
    Directory dirTemp = Directory.current;

    final resourceSync = ResourceProvider( 
      dirTarget: Directory( path.join( dirTemp.path, '../temp/resources' ).toString() )  
    );

    //print(jsonEncode( ResourceStat(size:1,mtime:DateTime.now()) ));

    List<Resource> list = await resourceSync.getFiles( );
    await resourceSync.sync( 'http://localhost:4000/resources' );
  });
}
