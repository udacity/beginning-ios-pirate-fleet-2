//
//  GridViewController.swift
//  Pirate Fleet
//
//  Created by Jarrod Parkes on 8/14/15.
//  Copyright © 2015 Udacity, Inc. All rights reserved.
//

import UIKit

// MARK: - GridViewController

class GridViewController {
    
    // MARK: Properties
    
    var gridView: GridView
    var ships: [Ship] = []
    var shipCounts: [ShipSize:Int] = [
        .Small: 0,
        .Medium: 0,
        .Large: 0,
        .XLarge: 0
    ]
    var mineCount = 0
    var seamonsterCount = 0
    
    // MARK: Initializers
    
    init(frame: CGRect, isInteractive: Bool = false) {
        gridView = GridView(frame: frame)
        gridView.isInteractive = isInteractive
    }
    
    func reset() {
        ships.removeAll(keepCapacity: true)
        for shipSize in shipCounts.keys {
            shipCounts[shipSize] = 0
        }
        mineCount = 0
        gridView.reset()
        gridView.setNeedsDisplay()
    }
    
    // MARK: Add Ship
    
    func addShip(ship: Ship, playerType: PlayerType = .Human) -> Bool {
        
        guard isShipRequired(ship) else {
            let shipSize = ShipSize(rawValue: ship.length)!
            if playerType == .Human { print("ERROR: Cannot add \(ship). You already have enough \(shipSize) ships.") }
            return false
        }
        
        guard !isShipOutOfBounds(ship) else {
            return false
        }
        
        guard !isShipOverlapping(ship) else {
            return false
        }
        
        let start = ship.location, end = ShipEndLocation(ship)
        
        for x in start.x...end.x {
            for y in start.y...end.y {
                
                
                ship.hitTracker.cellsHit[gridView.grid[x][y].location] = false
                
                gridView.grid[x][y].containsObject = true
                gridView.grid[x][y].ship = ship
                
                // place "front-end" of ship
                if x == start.x && y == start.y {
                    if ship.isVertical {
                        gridView.markShipPiece(GridLocation(x: x, y: y), orientation: .EndUp, playerType: playerType, isWooden: ship.isWooden)
                    } else {
                        gridView.markShipPiece(GridLocation(x: x, y: y), orientation: .EndLeft, playerType: playerType, isWooden: ship.isWooden)
                    }
                    continue
                }
                
                // place "back-end" of ship
                if x == end.x && y == end.y {
                    if ship.isVertical {
                        gridView.markShipPiece(GridLocation(x: x, y: y), orientation: .EndDown, playerType: playerType, isWooden: ship.isWooden)
                    } else {
                        gridView.markShipPiece(GridLocation(x: x, y: y), orientation: .EndRight, playerType: playerType, isWooden: ship.isWooden)
                    }
                    continue
                }
                
                // place middle piece of ship
                gridView.markShipPiece(GridLocation(x: x, y: y), orientation: ((ship.isVertical) ? .BodyVert : .BodyHorz), playerType: playerType, isWooden: ship.isWooden)
            }
        }
        
        ships.append(ship)
        shipCounts[ShipSize(rawValue: ship.length)!]! += 1
        return true
    }
    
    // MARK: Add Mine
    
    func addMine(mine: _Mine_, playerType: PlayerType = .Human) -> Bool {
        
        let x = mine.location.x, y = mine.location.y

        guard mineCount < Settings.RequiredMines && !gridView.grid[x][y].containsObject else {
            return false
        }
        
        gridView.grid[x][y].containsObject = true
        gridView.grid[x][y].mine = mine
        gridView.markMine(mine, hidden: ((playerType == .Computer) ? true : false))
        mineCount++
        return true
    }
    
    //MARK: Add Seamonster
    func addSeamonster(seamonster: Seamonster, playerType: PlayerType = .Human) -> Bool {
        
        let x = seamonster.location.x, y = seamonster.location.y
        
        guard seamonsterCount < Settings.RequiredSeamonsters && !gridView.grid[x][y].containsObject else {
            return false
        }
        
        gridView.grid[x][y].containsObject = true
        gridView.grid[x][y].seamonster = seamonster
        gridView.markSeamonster(seamonster, hidden: ((playerType == .Computer) ? true : false))
        seamonsterCount++
        return true
    }

    // MARK: Fire Cannon
    
    func fireCannonAtLocation(location: GridLocation) -> Bool {
        
        let x = location.x, y = location.y
        
        guard gridView.grid[x][y].containsObject else {
            return false
        }
        
        gridView.grid[x][y].ship?.hitTracker.cellsHit[location] = true
        if let mine = gridView.grid[x][y].mine {
            gridView.markMineHit(mine)
        } else if let seamonster = gridView.grid[x][y].seamonster {
            gridView.markSeamonsterHit(seamonster)
        } else {
            gridView.markHit(location)
        }
        return true
    }
}

// MARK: - Pre-Game Checks

extension GridViewController {
    
    func hasRequiredShips() -> Bool {
        for (shipType, count) in shipCounts {
            if count != Settings.RequiredShips[shipType] {
                return false
            }
        }
        return true
    }
    
    func hasRequiredMines() -> Bool {
        return mineCount == Settings.RequiredMines
    }

    func hasRequiredSeamonsters() -> Bool {
        return seamonsterCount == Settings.RequiredSeamonsters
    }
}

// MARK: - In-Game Checks

extension GridViewController {
    
    func checkSink(location: GridLocation) -> Bool {
        guard (gridView.grid[location.x][location.y].mine == nil) else {
            return false
        }
        
        if let ship = gridView.grid[location.x][location.y].ship {
            return ship.sunk
        } else {
            return false
        }
    }
    
    func checkForWin() -> Bool {
        for ship in ships {
            if ship.sunk == false {
                return false
            }
        }
        return true
    }
    
    func numberSunk() -> Int {
        var numberSunk = 0
        for ship in ships {
            if ship.sunk == true {
                numberSunk++
            }
        }
        return numberSunk
    }
}

// MARK: - Adding Ship Checks

extension GridViewController {
        
    private func isShipOutOfBounds(ship: Ship) -> Bool {
        let start = ship.location, end = ShipEndLocation(ship)
        return (end.x >= Settings.DefaultGridSize.width || end.y >= Settings.DefaultGridSize.height || start.x < 0 || end.x < 0)
    }
    
    private func isShipRequired(ship: Ship) -> Bool {
        let shipSize = ShipSize(rawValue: ship.length)!
        return shipCounts[shipSize] < Settings.RequiredShips[shipSize]
    }
    
    private func isShipOverlapping(ship: Ship) -> Bool {
        let start = ship.location, end = ShipEndLocation(ship)
        for x in start.x...end.x {
            for y in start.y...end.y {
                if gridView.grid[x][y].containsObject { return true }
            }
        }
        return false
    }
}