# TableSectionsAndAnimatedUpdate
How to Allow limited Selections in some but not all TableView Sections

This project was developed in response to [this StackOverlow question][1].

My answer:

Fundimentally the best solution (IMHO) for tableviews is to create a view model for your table, manipulate the data as required, then reflect that data in the table. Then, you do everything possible to have the table react to data changes as opposed to trying to use the table view itself to reflect data or state.

I created a project that does what you want and you can retrieve it [here][1].

The view data is contained here:

    let pilots = "Pilots"
    let crew = "Crew"
    let passengers = "Passengers"

    var sections: [String] = []
    var multipleSelectionsAllowed: Set<String> = []

    var members: [String: [String]] = [:]
    var selectedMembers: Set<String> = []

the first three string constants allow us to index into the data, and initialized:

    sections = [pilots, crew, passengers] // initial ordering of sections
    multipleSelectionsAllowed = [passengers]

The data is created programmatically, see the attached project or the full code attached below.

You said the sections may change, so `sections` is a variable and we'll change it later on.

`selectedMembers` contains a `hash` of the `type` (i.e. Pilot, Crew, or Passenger and their name, so it should be unique. This array will reflect the current selections, as data and not indexPaths.

But, we need indexPaths to reflect the `isSelected` UI changes: fine, we'll use two functions for this:

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

Also, something I've found very useful in the past is to put the code that changes the look of a cell in a single place, and call it when a cell is created or changed. You won't get out of sync over time as the UI changes too.

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

You need both because in some cases you only have an indexPath, not the cell.

Note that you use the above methods when creating cells:

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)

        let section = sections[indexPath.section]
        guard let names = members[section] else { fatalError() }
        let name = names[indexPath.row]

        cell.textLabel?.text = name

        updateCell(cell, atIndexPath: indexPath)
        return cell
    }


When the tableView detects a selection, you will first look at the existing selected data, and first remove that selection from your data, then update any delected cell's UI:

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

Then, handle the selection method:

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let section = sections[indexPath.section]
        guard let names = members[section] else { fatalError() }
        let name = names[indexPath.row]
        let hash = sectionNameToHash(section: section, name: name)

        selectedMembers.insert(hash)
        print("SELECTED THE CELL AT", hash)
        updateCell(atIndexPath: indexPath)
    }

Voila - everything works as you want. But, even better, you can re-arrange the sections as you said you do and get everything properly selected. The example code re-arranges and animates the sections 5 seconds after you select the first row/column, using the tableView's `performBatchUpdates` method - no `reloadData`!

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

The `deleteRows/insertRows` erases selections in those sections, so the above code uses the known selected members to inform the tableView of list of selections, even if the cells for each are not visible.


  [1]: https://stackoverflow.com/q/59095550/1633251
