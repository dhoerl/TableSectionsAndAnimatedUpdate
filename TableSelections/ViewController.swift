//
//  ViewController.swift
//  TableSelections
//
//  Created by David Hoerl on 12/3/19.
//  Copyright © 2019 Self. All rights reserved.
//

import UIKit

private final class MyCell: UITableViewCell {
    override var reuseIdentifier: String? { "cell" }
}

final class ViewController: UITableViewController {

    let pilots = "Pilots"
    let crew = "Crew"
    let passengers = "Passengers"

    var sections: [String] = []
    var multipleSelectionsAllowed: Set<String> = []

    var members: [String: [String]] = [:]
    var selectedMembers: Set<String> = []

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(MyCell.self, forCellReuseIdentifier: "cell")
        tableView.allowsMultipleSelection = true

        sections = [pilots, crew, passengers] // initial ordering of sections
        multipleSelectionsAllowed = [passengers]

        constructData()

//        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
//            self.scramble()
//        }
    }

    private func constructData() {
        var array: [String] = []
        (1..<3).forEach { array.append("Pilot \($0)")}
        members[pilots] = array
        array.removeAll()

        (1..<6).forEach { array.append("Crew \($0)")}
        members[crew] = array
        array.removeAll()

        (1..<250).forEach { array.append("Passenger \($0)")}
        members[passengers] = array
    }

    // MARK: - Helpers -

    typealias KeyToValues = (section: String, name: String)

    func sectionNameToHash(section: String, name: String) -> String {
        let hash = section + "|" + name
        return hash
    }


    func hashToSectionName(hash: String) -> KeyToValues {
        let array = hash.components(separatedBy: "|")
        assert(array.count == 2)
        return (array[0], array[1])
    }

    func nameToIndexPath(name: String) -> IndexPath {
        for (section, type) in sections.enumerated() {
            let people = members[type]!
            if let row = people.firstIndex(of: name) {
                return IndexPath(row: row, section: section)
            }
        }
        fatalError("Never Found \(name)")
    }

    func indexPathToName(indexPath: IndexPath) -> String {
        let type = sections[indexPath.section]
        let name = members[type]![indexPath.row]
        return name
    }

}

// MARK: - UITableViewDataSource -

extension ViewController /*: UITableViewDataSource */ {

    override func numberOfSections(in: UITableView) -> Int {
        return sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let type = sections[section]
        let count = members[type]?.count ?? 0 // could use guard here too and crash if nil
        return count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)

        let section = sections[indexPath.section]
        guard let names = members[section] else { fatalError() }
        let name = names[indexPath.row]

        cell.textLabel?.text = name

        updateCell(cell, atIndexPath: indexPath)
        return cell
    }

    func updateCell(atIndexPath indexPath: IndexPath) {
        let cells = tableView.visibleCells
        for cell in cells {
            guard let path = tableView.indexPath(for: cell) else { continue }
            if path == indexPath {
                updateCell(cell, atIndexPath: indexPath)
            }
        }
    }

    func updateCell(_ cell: UITableViewCell, atIndexPath indexPath: IndexPath) {
        let section = sections[indexPath.section]
        guard let names = members[section] else { fatalError() }
        let name = names[indexPath.row]

        let hash = sectionNameToHash(section: section, name: name)
        let shouldBeSelected = selectedMembers.contains(hash)

        if shouldBeSelected {
            cell.accessoryType = .checkmark
            print("SELECTED", hash)
        } else {
            cell.accessoryType = .none
            print("DESELECTED", hash)
        }
    }

}

extension ViewController /* : UITableViewDelegate */ {

    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        let section = sections[indexPath.section]
        guard let names = members[section] else { fatalError() }

        let canMultipleSelect = multipleSelectionsAllowed.contains(section)

        if !canMultipleSelect, let paths = tableView.indexPathsForSelectedRows {
            for path in paths {
                if path.section == indexPath.section {
                    let name = names[path.row]
                    let hash = sectionNameToHash(section: section, name: name)
                    selectedMembers.remove(hash)
                    updateCell(atIndexPath: path)
                    tableView.deselectRow(at: path, animated: true)
                }
            }
        }
        return indexPath
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let section = sections[indexPath.section]
        guard let names = members[section] else { fatalError() }
        let name = names[indexPath.row]
        let hash = sectionNameToHash(section: section, name: name)

        selectedMembers.insert(hash)
        print("SELECTED THE CELL AT", hash)
        updateCell(atIndexPath: indexPath)

        if indexPath.section == 0 && indexPath.row == 0 {
            let newSections = [crew, pilots, passengers]

            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                self.scramble(newSections: newSections, completion: { (_) in
                    for hash in self.selectedMembers {
                        let value = self.hashToSectionName(hash: hash)
                        guard
                            let sectionNumber = self.sections.firstIndex(of: value.section),
                            let names = self.members[value.section],
                            let row = names.firstIndex(of: value.name)
                        else { fatalError() }

                        let indexPath = IndexPath(row: row, section: sectionNumber)
                        self.tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
                    }
                })
            }

        }
    }

    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        print("DESELECTED THE CELL AT", hash)

        let section = sections[indexPath.section]
        guard let names = members[section] else { fatalError() }
        let name = names[indexPath.row]
        let hash = sectionNameToHash(section: section, name: name)
        selectedMembers.remove(hash)

        updateCell(atIndexPath: indexPath)
    }

}


/*

APPLE DOCS:
Deletes are processed before inserts in batch operations.

This means the indexes for the deletions are processed relative to the indexes of the table view’s state before the batch operation,
and the indexes for the insertions are processed relative to the indexes of the state after all the deletions in the batch operation.
*/
extension ViewController {

    func scramble(newSections: [String], completion: @escaping (Bool) -> Void ) {

        tableView.performBatchUpdates({
#if true
            // remove a slew of stuff - indexes key'd to existing data (so it better not have changed)
            let deletions = members[pilots]! + members[crew]!
            let paths = deletions.map({ nameToIndexPath(name: $0) } )

            // 1: remove the old indexes with the view model data untouched
            self.tableView.deleteRows(at: paths, with: .automatic)

            // 2a. now we update our data to reflect what we just did
//            members[pilots] = nil
//            members[crew] = nil

            // 2b: now update the data by adding in a few new rows
            sections = newSections
            let nPaths = deletions.map({ nameToIndexPath(name: $0) } )
            // 3: now update the tableView
            self.tableView.insertRows(at: nPaths, with: .automatic)
#endif
#if false
            // remove a slew of stuff - indexes key'd to existing data (so it better not have changed)
            let deletions = [
                "Pilot 2", "Pilot 3", "Pilot 4", "Pilot 5",
                "Crew 2", "Crew 3", "Crew 4", "Crew 5", "Crew 6", "Crew 7", "Crew 8", "Crew 9",
            ]
            let paths = deletions.map({ nameToIndexPath(name: $0) } )

            // 1: remove the old indexes with the view model data untouched
            self.tableView.deleteRows(at: paths, with: .automatic)
            // 2a. now we update our data to reflect what we just did
            for type in sections {
                var people = members[type]!
                people.removeAll(where: { deletions.contains($0) })
                members[type] = people
            }
            // 2b: now update the data by adding in a few new rows

            let newPilot = "Ted Striker"
            let newCrew = "Elaine Dickinson"
            let newPilotPath: IndexPath
            let newCrewPath: IndexPath
            do {
                var people = members[pilots]!
                people.insert(newPilot, at: 1)
                members[pilots] = people
                newPilotPath = IndexPath(row: 1, section: sections.firstIndex(of: pilots)!)
            }
            do {
                var people = members[crew]!
                people.insert(newCrew, at: 0)
                members[crew] = people
                newCrewPath = IndexPath(row: 0, section: sections.firstIndex(of: crew)!)
            }
            // 3: now update the tableView
            self.tableView.insertRows(at: [newPilotPath, newCrewPath], with: .automatic)
#endif
        },
        completion: completion)
    }

}
