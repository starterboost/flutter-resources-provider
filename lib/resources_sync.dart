library resources_sync;

import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class _ResourceStat{
  _ResourceStat();

  factory _ResourceStat.fromJson(Map<String, dynamic> json){
    return _ResourceStat();
  }
}
class _Resource{
  _Resource({@required this.path, @required this.stat});
  final String path;
  final _ResourceStat stat;

  factory _Resource.fromJson(Map<String, dynamic> json){
    return _Resource(
      path : json['path'],
      stat : _ResourceStat.fromJson( json['stat'] )
    );
  }
}

/// A Calculator.
class ResourceSync {
  ResourceSync({this.dirTarget,this.urlSource});

  final Directory dirTarget;
  final String urlSource;

  /// Returns [value] plus 1.
  Future<void> sync() async {
    //now that it's been created
    await dirTarget.exists().then( (exists) async {
      if( !exists )return dirTarget.create(recursive: true);
    });

    //get the full list of contents
    List<File> files = <File>[];
    await for (FileSystemEntity entity in dirTarget.list(recursive: true, followLinks: false)) {
      FileSystemEntityType type = await FileSystemEntity.type(entity.path);
      if ( type == FileSystemEntityType.file ) {
        files.add(entity);
        print("Item: ${entity.path}");
      }
    }

    print( "Files: ${files.length}" );

    return http.get( urlSource )
    .then( ( response ) async {
      List<dynamic> items = List<dynamic>.from(jsonDecode( response.body ));
      
      print('Response: ${response.statusCode} ${items.length}');

      List<_Resource> resources = items.map( ( item ){
        return _Resource.fromJson( item ); 
      }).toList();

      //loop through all of our resources
      for( _Resource resource  in resources ){
        //check if this exists
        File file = File( path.join( dirTarget.path, resource.path ) );
        bool exists = await file.exists();
        
        files.removeWhere( ( item ){
          return item.path == file.path ? true : false;
        });

        if( !exists ){
          await file.create(recursive: true);
          //download and save file
          await new HttpClient().getUrl(Uri.parse(
            path.join( urlSource, resource.path )
          ))
          .then((HttpClientRequest request) => request.close())
          .then((HttpClientResponse response) => 
              response.pipe( file.openWrite() ));
        }
      }

      //delete any outstanding files
      print( "Files after: ${files.length}" );
      for( FileSystemEntity file in files ){
        await file.delete();
      }

    })
    .catchError(( err ){
      print("$err");
    })
    .then( ( _ ) {
      return;
    });

  }
}
