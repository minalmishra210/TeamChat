//
//  ApiManager.swift
//  TeamChat
//
//  Created by Meenal Mishra on 27/07/24.
//

import Foundation



class APIManager {
    
    static let shared = APIManager() // Singleton instance

    private init() {}
    
    func performPostAsyncRequest(urlString: String, requestBody: [String: String]) async -> Data? {
  
        guard let url = URL(string: urlString) else {
            print("Error: Invalid URL")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyComponents = requestBody.map { "\($0.key)=\($0.value)" }
        let bodyString = bodyComponents.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
//        do {
//            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
//        } catch {
//            print("Error: Failed to serialize request body")
//            return nil
//        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                return data
            } else {
                print("Error: Server responded with status code \(String(describing: (response as? HTTPURLResponse)?.statusCode))")
                return nil
            }
        } catch {
            print("Error: Network request failed with error \(error.localizedDescription)")
            return nil
        }
    }
    
   
    func fetchChannels(authToken: String) async throws -> [Channel] {
        guard let url = URL(string: "https://mofa.onice.io/teamchatapi/channels.list") else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let parameters = [
            "token": authToken,
            "include_unread_count": "true",
            "exclude_members": "true",
            "include_permissions": "false"
        ]
        request.httpBody = parameters.map { "\($0.key)=\($0.value)" }
                                     .joined(separator: "&")
                                     .data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
            }
            
            let channelListResponse = try JSONDecoder().decode(ChannelListResponse.self, from: data)
            return channelListResponse.channels
        } catch {
            throw error
        }
    }
}
