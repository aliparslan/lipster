import Foundation
import SQLite3
import UIKit

@MainActor
final class DatabaseManager {
    private var db: OpaquePointer?

    var databasePath: String {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return ""
        }
        return docs.appendingPathComponent("ripper.db").path
    }

    init() {
        open()
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    private func open() {
        let path = databasePath
        guard !path.isEmpty, FileManager.default.fileExists(atPath: path) else {
            print("[DatabaseManager] ripper.db not found at \(path)")
            return
        }
        if sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            print("[DatabaseManager] Failed to open database: \(errorMessage)")
            db = nil
        }
    }

    private func close() {
        if let db {
            sqlite3_close(db)
        }
        db = nil
    }

    private var errorMessage: String {
        if let db {
            return String(cString: sqlite3_errmsg(db))
        }
        return "No database connection"
    }

    // MARK: - Songs

    func loadSongs() -> [Song] {
        let sql = """
            SELECT id, spotify_id, title, artist, album_artist, album, year, track_number, \
            disc_number, duration_ms, file_path, downloaded \
            FROM songs WHERE downloaded = 1 ORDER BY artist, album, disc_number, track_number
            """
        return query(sql: sql, bind: { _ in }, map: mapSong)
    }

    func searchSongs(query searchText: String) -> [Song] {
        let sql = """
            SELECT id, spotify_id, title, artist, album_artist, album, year, track_number, \
            disc_number, duration_ms, file_path, downloaded \
            FROM songs WHERE downloaded = 1 AND (title LIKE ?1 OR artist LIKE ?1 OR album LIKE ?1) ORDER BY title
            """
        return query(sql: sql, bind: { stmt in
            let pattern = "%\(searchText)%"
            sqlite3_bind_text(stmt, 1, (pattern as NSString).utf8String, -1, nil)
        }, map: mapSong)
    }

    func loadSongsForAlbum(albumId: Int64) -> [Song] {
        let sql = """
            SELECT s.id, s.spotify_id, s.title, s.artist, s.album_artist, s.album, s.year, \
            s.track_number, s.disc_number, s.duration_ms, s.file_path, s.downloaded \
            FROM songs s \
            JOIN album_songs aso ON aso.song_id = s.id \
            WHERE aso.album_id = ?1 AND s.downloaded = 1 \
            ORDER BY s.disc_number, aso.track_number
            """
        return query(sql: sql, bind: { stmt in
            sqlite3_bind_int64(stmt, 1, albumId)
        }, map: mapSong)
    }

    func loadSongsForPlaylist(playlistId: Int64) -> [Song] {
        let sql = """
            SELECT s.id, s.spotify_id, s.title, s.artist, s.album_artist, s.album, s.year, \
            s.track_number, s.disc_number, s.duration_ms, s.file_path, s.downloaded \
            FROM songs s \
            JOIN playlist_songs ps ON ps.song_id = s.id \
            WHERE ps.playlist_id = ?1 AND s.downloaded = 1 \
            ORDER BY ps.position
            """
        return query(sql: sql, bind: { stmt in
            sqlite3_bind_int64(stmt, 1, playlistId)
        }, map: mapSong)
    }

    private func mapSong(_ stmt: OpaquePointer?) -> Song {
        Song(
            id: sqlite3_column_int64(stmt, 0),
            spotifyId: columnText(stmt, 1),
            title: columnText(stmt, 2) ?? "Unknown",
            artist: columnText(stmt, 3) ?? "Unknown Artist",
            albumArtist: columnText(stmt, 4),
            album: columnText(stmt, 5),
            year: columnInt(stmt, 6),
            trackNumber: columnInt(stmt, 7),
            discNumber: columnInt(stmt, 8),
            durationMs: Int(sqlite3_column_int(stmt, 9)),
            filePath: columnText(stmt, 10) ?? "",
            downloaded: sqlite3_column_int(stmt, 11) != 0
        )
    }

    // MARK: - Albums

    func loadAlbums() -> [Album] {
        let sql = """
            SELECT a.id, a.spotify_id, a.name, a.artist, a.year, a.cover_path \
            FROM albums a \
            WHERE EXISTS (SELECT 1 FROM album_songs aso JOIN songs s ON s.id = aso.song_id WHERE aso.album_id = a.id AND s.downloaded = 1) \
            ORDER BY a.artist, a.year, a.name
            """
        return query(sql: sql, bind: { _ in }, map: mapAlbum)
    }

    private func mapAlbum(_ stmt: OpaquePointer?) -> Album {
        Album(
            id: sqlite3_column_int64(stmt, 0),
            spotifyId: columnText(stmt, 1),
            name: columnText(stmt, 2) ?? "Unknown Album",
            artist: columnText(stmt, 3) ?? "Unknown Artist",
            year: columnInt(stmt, 4),
            coverPath: columnText(stmt, 5)
        )
    }

    // MARK: - Playlists

    func loadPlaylists() -> [Playlist] {
        let sql = """
            SELECT p.id, p.spotify_id, p.name, p.description, p.cover_path, p.folder_id \
            FROM playlists p \
            WHERE EXISTS (SELECT 1 FROM playlist_songs ps JOIN songs s ON s.id = ps.song_id WHERE ps.playlist_id = p.id AND s.downloaded = 1) \
            ORDER BY p.name
            """
        return query(sql: sql, bind: { _ in }, map: mapPlaylist)
    }

    private func mapPlaylist(_ stmt: OpaquePointer?) -> Playlist {
        Playlist(
            id: sqlite3_column_int64(stmt, 0),
            spotifyId: columnText(stmt, 1),
            name: columnText(stmt, 2) ?? "Untitled Playlist",
            description: columnText(stmt, 3),
            coverPath: columnText(stmt, 4),
            folderId: sqlite3_column_type(stmt, 5) == SQLITE_NULL ? nil : sqlite3_column_int64(stmt, 5)
        )
    }

    // MARK: - Folders

    func loadFolders() -> [Folder] {
        let sql = "SELECT id, name, parent_id FROM folders ORDER BY name"
        return query(sql: sql, bind: { _ in }, map: mapFolder)
    }

    private func mapFolder(_ stmt: OpaquePointer?) -> Folder {
        Folder(
            id: sqlite3_column_int64(stmt, 0),
            name: columnText(stmt, 1) ?? "Untitled Folder",
            parentId: sqlite3_column_type(stmt, 2) == SQLITE_NULL ? nil : sqlite3_column_int64(stmt, 2)
        )
    }

    // MARK: - Artist Cover Art

    /// Loads cover art for an artist by finding their most recent album's cover.
    func loadCoverForArtist(name: String) -> UIImage? {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        // Find the first album by this artist that has a cover
        let sql = """
            SELECT a.cover_path, a.name, a.artist \
            FROM albums a \
            WHERE a.artist = ?1 \
            AND EXISTS (SELECT 1 FROM album_songs aso JOIN songs s ON s.id = aso.song_id WHERE aso.album_id = a.id AND s.downloaded = 1) \
            ORDER BY a.year DESC LIMIT 1
            """
        let albums: [(coverPath: String?, albumName: String, artist: String)] = query(sql: sql, bind: { stmt in
            sqlite3_bind_text(stmt, 1, (name as NSString).utf8String, -1, nil)
        }, map: { stmt in
            (
                coverPath: columnText(stmt, 0),
                albumName: columnText(stmt, 1) ?? "",
                artist: columnText(stmt, 2) ?? ""
            )
        })

        guard let album = albums.first else { return nil }

        // Try cover_path from DB
        if let coverPath = album.coverPath, !coverPath.isEmpty {
            let url = docs.appendingPathComponent(coverPath)
            if let img = UIImage(contentsOfFile: url.path) {
                return img
            }
        }

        // Fallback: look in music/Artist/Album/cover.jpg
        let safe = { (s: String) -> String in
            let illegal = "\\/:*?\"<>|"
            var result = s
            for ch in illegal { result = result.replacingOccurrences(of: String(ch), with: "_") }
            return result.trimmingCharacters(in: .whitespaces)
        }
        let coverURL = docs
            .appendingPathComponent("music")
            .appendingPathComponent(safe(album.artist))
            .appendingPathComponent(safe(album.albumName))
            .appendingPathComponent("cover.jpg")
        return UIImage(contentsOfFile: coverURL.path)
    }

    // MARK: - Helpers

    private func query<T>(sql: String, bind: (OpaquePointer?) -> Void, map: (OpaquePointer?) -> T) -> [T] {
        guard let db else { return [] }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            print("[DatabaseManager] Prepare failed: \(errorMessage)")
            return []
        }
        defer { sqlite3_finalize(stmt) }
        bind(stmt)
        var results: [T] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(map(stmt))
        }
        return results
    }

    private func columnText(_ stmt: OpaquePointer?, _ index: Int32) -> String? {
        guard let ptr = sqlite3_column_text(stmt, index) else { return nil }
        return String(cString: ptr)
    }

    private func columnInt(_ stmt: OpaquePointer?, _ index: Int32) -> Int? {
        if sqlite3_column_type(stmt, index) == SQLITE_NULL { return nil }
        return Int(sqlite3_column_int(stmt, index))
    }
}
