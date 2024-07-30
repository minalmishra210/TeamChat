//
//  ChannelScreenViewController.swift
//  TeamChat
//
//  Created by Meenal Mishra on 29/07/24.
//

import UIKit
import CoreData

class ChannelScreenViewController: UIViewController , UICollectionViewDataSource, NSFetchedResultsControllerDelegate, UICollectionViewDelegateFlowLayout {
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    var fetchedResultsController: NSFetchedResultsController<ChanelEntity>!
    var managedContext: NSManagedObjectContext?
    var token : String?
    private var channelsByGroup: [String: [ChanelEntity]] = [:]
    private var groupFolderNames: [String] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.register(UINib(nibName: "ChannelListHeaderView", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "ChannelListHeaderView")
        collectionView.dataSource = self
        collectionView.delegate = self
        let backButton = UIBarButtonItem(title: "Back", style: .plain, target: self, action: #selector(backButtonTapped))
        let logoutButton = UIBarButtonItem(title: "LogOut", style: .plain, target: self, action: #selector(logoutButtonTapped))
        navigationItem.leftBarButtonItem = backButton
        navigationItem.rightBarButtonItem = logoutButton
        fetchChannelsFromAPI()
    }
    
    @objc func backButtonTapped() {
        //deleteFromDatabase()
        navigateToLoginScreen()
    }
    
    @objc func logoutButtonTapped() {
        deleteTokenFromKeychain()
        navigateToLoginScreen()
    }
    
    func setupFetchedResultsController() {
        let fetchRequest: NSFetchRequest<ChanelEntity> = ChanelEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "groupFolderName", ascending: true)]
        
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                              managedObjectContext: managedContext!,
                                                              sectionNameKeyPath: nil,
                                                              cacheName: nil)
        fetchedResultsController.delegate = self
        
        do {
            try fetchedResultsController.performFetch()
        } catch {
            print("Failed to fetch channels: \(error)")
        }
        organizeChannelsByGroup()
    }
    
    func fetchChannelsFromAPI() {
        Task {
            do {
                let channels = try await APIManager.shared.fetchChannels(authToken: token ?? "")
                DispatchQueue.main.async { [weak self] in
                    self?.saveChannelsToDatabase(channels)
                }
            } catch {
                print("Failed to fetch channels: \(error)")
            }
        }
    }
    
    func saveChannelsToDatabase(_ channels: [Channel]) {
        channels.forEach { channel in
            let channelEntity = ChanelEntity(context: managedContext!)
            channelEntity.id = channel.id
            channelEntity.name = channel.name
            channelEntity.groupFolderName = channel.groupFolderName
        }
        do {
            try managedContext!.save()
            setupFetchedResultsController()
        } catch {
            print("Failed to save channels: \(error)")
        }
    }
    
    func organizeChannelsByGroup() {
        guard let channels = fetchedResultsController.fetchedObjects else { return }
        channelsByGroup.removeAll()
        for channel in channels {
            let groupName = channel.groupFolderName ?? "Unknown"
            if channelsByGroup[groupName] != nil {
                channelsByGroup[groupName]?.append(channel)
            } else {
                channelsByGroup[groupName] = [channel]
            }
        }
        groupFolderNames = Array(channelsByGroup.keys).sorted()
        collectionView.reloadData()
    }
    
    func deleteFromDatabase() {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "ChannelEntity")
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try managedContext!.execute(batchDeleteRequest)
        } catch {
            print("Failed to delete \(error)")
        }
    }
    
    func deleteTokenFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "authToken"
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess {
            print("Successfully deleted the auth token from Keychain.")
        } else if status == errSecItemNotFound {
            print("No auth token found in Keychain.")
        } else {
            print("Failed to delete the auth token from Keychain with status code \(status).")
        }
    }
    
    func navigateToLoginScreen() {
        navigationController?.popToRootViewController(animated: true)
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return groupFolderNames.count
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        
        guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "ChannelListHeaderView", for: indexPath) as? ChannelListHeaderView else {
            fatalError("Unable to dequeue")
        }
        let groupName = groupFolderNames[indexPath.section]
        header.titleLabel.text = groupName
        return header
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let groupName = groupFolderNames[section]
        return channelsByGroup[groupName]?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ChannelCell", for: indexPath) as? ChannelCell else {
            fatalError("Unable to dequeue")
        }
        let groupName = groupFolderNames[indexPath.section]
        if let channel = channelsByGroup[groupName]?[indexPath.item] {
            cell.configure(with: channel)
        } else {
            print("No channel ")
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.bounds.width, height: 50)
    }
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        organizeChannelsByGroup()
    }
}

struct Channel: Codable {
    let id: String
    let name: String
    let groupFolderName: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case groupFolderName = "group_folder_name"
    }
}

struct ChannelListResponse: Codable {
    let channels: [Channel]
}

class ChannelCell: UICollectionViewCell {
    
    @IBOutlet weak var nameLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func configure(with channel: ChanelEntity) {
        nameLabel.text = channel.name
    }
}

class ChannelListHeaderView: UICollectionReusableView {
    
    @IBOutlet weak var titleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
}

