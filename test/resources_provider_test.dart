import 'package:flutter_test/flutter_test.dart';

import 'package:resources_provider/resources_provider.dart';

import 'dart:io';
import 'package:path/path.dart' as path;

void main() {
  test('Creates a resource sync', () async {
    Directory dirTemp = Directory.current;

    final resourceSync = ResourceProvider( 
      dirTarget: Directory( path.join( dirTemp.path, '../temp/resources' ).toString() )  
    );

    //get the current list of files
    List<Resource> list = await resourceSync.getFiles();
    //resync the content with an online provider
    await resourceSync.sync( 'http://localhost:4000/resources' );
  });
}
