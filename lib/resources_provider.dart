library resources_sync;

import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';
import 'package:convert/convert.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart' as crypto;

final RegExp _regExpTrailingSlash = RegExp(r"\/$");

class ResourceStat{
  ResourceStat({
    @required this.size,
    @required this.mtime,
  });
  final int size;
  final DateTime mtime;

  factory ResourceStat.fromJson(Map<String, dynamic> json){
    return ResourceStat(
      size : json['size'],
      mtime : DateTime.parse(json['mtime']),
    );
  }

  Map<String, dynamic> toJson() => {
    'size': size,
    'mtime': mtime.toString()
  };
}
class Resource{
  Resource({
    @required this.path, 
    @required this.hash, 
    @required this.stat
  });
  final String path;
  final String hash;
  final ResourceStat stat;

  Map<String, dynamic> toJson() => {
    'path': path,
    'hash': hash,
    'stat' : stat
  };


  factory Resource.fromJson(Map<String, dynamic> json){
    return Resource(
      path : json['path'],
      hash : json['hash'],
      stat : ResourceStat.fromJson( json['stat'] )
    );
  }

  static Future<Resource> createFromFileSystemEntity( String path, FileSystemEntity file ) async {
    final FileStat stat = await file.stat();

    final int size = stat.size;
    final DateTime mtime = stat.modified;

    final String hash = await fileHash( file );

    return Resource(
      path: path,
      hash: hash,
      stat: ResourceStat(
        size : size,
        mtime: mtime
      )
    );
  }

  static Future<String> fileHash( File file ) async {
    List<int> content = await file.readAsBytes();
    crypto.MD5 md5 = crypto.md5;
    crypto.Digest digest = md5.convert(content);
            
    return hex.encode(digest.bytes);
  }
}

/// A Resource Provider.
class ResourceProvider {
  ResourceProvider({this.dirTarget});

  static bool _isValidFile( String path ){
    return ['.cache.json'].contains( path ) ? false : true;
  }

  final Directory dirTarget;
  List<Resource> _cache;

  String _relativePath(String pathSource) => path.relative( pathSource, from: dirTarget.path );

  File get _fileCache => File( path.join( dirTarget.path, '.cache.json' ) );

  Future<List<Resource>> getFiles( {String dirFilter = ""} ) async {
    //format the dirFilter
    if( dirFilter.length > 0 ){
      //make sure it's correctly formatted
      if( !_regExpTrailingSlash.hasMatch(dirFilter) ){
        dirFilter += "/";
      }
    }

    if( _cache == null ){
      //load up the resources
      bool cacheExists = await _fileCache.exists();
      _cache = cacheExists ? await _fileCache.readAsString().then( ( data ){
        //decode the data to json items
        List<dynamic> items = jsonDecode( data );
        //map the json data to _resources
        return items.map( ( item ){
          return Resource.fromJson( item ); 
        }).toList();
      } ) : [];
    }

    List<String> _cacheOldPaths = _cache.map( ( resource ) => resource.path ).toList();
    
    //need to rewalk the directory to make sure there are no change
    await for (FileSystemEntity entity in dirTarget.list(recursive: true, followLinks: false)) {
      FileSystemEntityType type = await FileSystemEntity.type(entity.path);
      if ( type == FileSystemEntityType.file ) {
        String pathRelative = _relativePath( entity.path );
        //only record valid files
        if( ResourceProvider._isValidFile( pathRelative ) ){
          //remove this reference from old paths that need to be deleted
          _cacheOldPaths.remove( pathRelative );
          //does this exist already
          Resource resource = getFile( pathRelative );
          if( resource == null ){
            //we need to create it
            resource = await Resource.createFromFileSystemEntity( pathRelative, entity );
            _cache.add( resource );
          }else{
            FileStat statEntity = await entity.stat();
            if( statEntity.modified != resource.stat.mtime ){
              //we need to update the reference
              _cache.remove( resource );
              resource = await Resource.createFromFileSystemEntity( pathRelative, entity );
              _cache.add( resource );
            }
          }
        }
      }
    }

    //delete any old unused files
    for( String pathFileOld in _cacheOldPaths ){
      File fileOld = File( path.join( dirTarget.path, pathFileOld ) );
      //remove it from the cache
      _cache.removeWhere( (resource) => resource.path == pathFileOld );
      //check if exists so we decide if we want to remove
      bool fileOldExists = await fileOld.exists();
      if( fileOldExists ){
        await fileOld.delete();
      }
    }

    this.saveCache();
    //filter the files based on dirFilter prefix provided
    return _cache.where( ( Resource resource ){
      return resource.path.startsWith( dirFilter ) ? true : false;
    }).toList();
  }

  Future<void> saveCache() async {
    JsonEncoder encoder = new JsonEncoder.withIndent('  ');
    String content = encoder.convert( _cache );
    await _fileCache.writeAsString( content );
    return;
  }

  Resource getFile( String path ){
    return ( _cache != null ) ? _cache.firstWhere( (item) => item.path == path, orElse: () => null ) : null;
  }

  void _removeFile( Resource resource ) async {
    _cache.remove( resource );
    File file = File( path.join( dirTarget.path, resource.path ) );
    bool exists = await file.exists();
    if( exists ){
      file.delete();
    }
  }

  /// Returns [value] plus 1.
  Future<void> sync( String urlSource ) async {
    //now that it's been created
    await dirTarget.exists().then( (exists) async {
      if( !exists )return dirTarget.create(recursive: true);
    });


    //get the full list of contents
    List<Resource> files = await this.getFiles();
    
    return http.get( urlSource )
    .then( ( response ) async {
      List<dynamic> items = List<dynamic>.from(jsonDecode( response.body ));
      
      //print('Response: ${response.statusCode} ${items.length}');
      List<Resource> resources = items.map( ( item ){
        return Resource.fromJson( item ); 
      }).toList();

      //loop through all of our resources
      for( Resource resource  in resources ){
        //check if this exists
        File file = File( path.join( dirTarget.path, resource.path ) );
        bool exists = await file.exists();
        
        Resource resourceOriginal = files.firstWhere( ( item ){
          return item.path == resource.path ? true : false;
        }, orElse:() => null );
        
        bool downloadFile = !exists;

        //remove the file from the list
        if( resourceOriginal != null ){
          files.remove( resourceOriginal );

          if( resourceOriginal.stat.size != resource.stat.size ){
            //print("enableDownload due to size");
            downloadFile = true;
          }else{

            if( resourceOriginal.hash != resource.hash ){
              //print("enableDownload due to hash");
              downloadFile = true;
            }
          }
        }
          
        

        if( downloadFile ){
          //print('Downloading ${file.path}');
          await file.create(recursive: true);
          //download and save file
          await new HttpClient().getUrl(Uri.parse(
            path.join( urlSource, resource.path )
          ))
          .then((HttpClientRequest request) => request.close())
          .then((HttpClientResponse response) => response.pipe( file.openWrite() ))
          .then(( _ ){
            //add this new resource
            if( resourceOriginal != null ){
              _cache.remove( resourceOriginal );
            }
            //add the newly updated resource to the list
            _cache.add( resource );
          });
        }
      }

      //delete any outstanding files
      for( Resource resource in files ){
        _removeFile( resource );
      }

      //save the cache
      await this.saveCache();

    })
    .then( ( _ ) {
      return;
    });

  }
}
