//
//  MapKitController.swift
//  MapLocation
//
//  Created by Ivan Pedrero on 9/17/19.
//  Copyright © 2019 Ivan Pedrero. All rights reserved.
//

import Foundation
import UIKit
import HealthKit

fileprivate enum ATError: Error {
    case notAvailable, missingType
}

class HealthKitController: UIViewController {
    
    @IBOutlet weak var dobLabel: UILabel!
    @IBOutlet weak var sexLabel: UILabel!
    @IBOutlet weak var bloodLabel: UILabel!
    @IBOutlet weak var heightLabel: UILabel!
    @IBOutlet weak var weightLabel: UILabel!
    @IBOutlet weak var energyLabel: UILabel!
    @IBOutlet weak var waterLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        authorize { (success, error) in
            print("HK Authorization finished - success: \(success); error: \(String(describing: error))")
            self.readCharacteristicsData()
            self.readEnergy()
            self.readWater()
            self.readHeight()
            self.readWeight()
        }
    }
    
    private func authorize(completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, ATError.notAvailable)
            return
        }

        guard
            let dob = HKObjectType.characteristicType(forIdentifier: .dateOfBirth),
            let sex = HKObjectType.characteristicType(forIdentifier: .biologicalSex),
            let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            let water = HKObjectType.quantityType(forIdentifier: .dietaryWater),
            let height = HKObjectType.quantityType(forIdentifier: .height),
            let weight = HKObjectType.quantityType(forIdentifier: .bodyMass),
            let bloodType = HKObjectType.characteristicType(forIdentifier: .bloodType) else {
                completion(false, ATError.missingType)
                return
        }
        
        let writing: Set<HKSampleType> = [water]
        let reading: Set<HKObjectType> = [dob, sex, energy, water, height, weight, bloodType]
        
        HKHealthStore().requestAuthorization(toShare: writing, read: reading, completion: completion)
    }
    
    private func readCharacteristicsData() {
        let store = HKHealthStore()
        do {
            let dobComponents = try store.dateOfBirthComponents()
            let sex = try store.biologicalSex().biologicalSex
            let blood = try store.bloodType().bloodType
            
            
            DispatchQueue.main.async {
                self.dobLabel.text = "Birthday: \(dobComponents.day!)/\(dobComponents.month!)/\(dobComponents.year!)"
                
                var sexType:String!
                switch(sex.rawValue){
                    case 1: sexType = "Female"
                    case 2: sexType = "Male"
                    case 3: sexType = "Other"
                    default: sexType = "Not Set"
                }
                self.sexLabel.text = "Sex: " + sexType
                
                var bloodType:String!
                switch (blood) {
                    case .aPositive:
                        bloodType = "A+"
                    case .aNegative:
                        bloodType = "A-"
                    case .bPositive:
                        bloodType = "B+"
                    case .bNegative:
                        bloodType = "B-"
                    case .abPositive:
                        bloodType = "AB+"
                    case .abNegative:
                        bloodType = "AB-"
                    case .oPositive:
                        bloodType = "O+"
                    case .oNegative:
                        bloodType = "O-"
                    case .notSet:
                        bloodType = "Not Set"
                @unknown default:
                    bloodType = "Not Set"
                }
                self.bloodLabel.text = "Blood: " + bloodType
            }
        } catch {
            print("Something went wrong: \(error)")
        }
    }
    
    private func readEnergy() {
        guard let energyType = HKSampleType.quantityType(forIdentifier: .activeEnergyBurned) else {
            print("Sample type not available")
            return
        }
        
        let last24hPredicate = HKQuery.predicateForSamples(withStart: Date().oneDayAgo, end: Date(), options: .strictEndDate)
        
        let energyQuery = HKSampleQuery(sampleType: energyType,
                                        predicate: last24hPredicate,
                                        limit: HKObjectQueryNoLimit,
                                        sortDescriptors: nil) {
                                            (query, sample, error) in
                                            
                                            guard
                                                error == nil,
                                                let quantitySamples = sample as? [HKQuantitySample] else {
                                                    print("Something went wrong: \(String(describing: error))")
                                                    return
                                            }
                                            
                                            let total = quantitySamples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: HKUnit.kilocalorie()) }
                                            print("Total kcal: \(total)")
                                            DispatchQueue.main.async {
                                                self.energyLabel.text = String(format: "Energy: %.1f kcal", total)
                                            }
        }
        HKHealthStore().execute(energyQuery)
    }
    
    private func readWater() {
        guard let waterType = HKSampleType.quantityType(forIdentifier: .dietaryWater) else {
            print("Sample type not available")
            return
        }
        
        let last24hPredicate = HKQuery.predicateForSamples(withStart: Date().oneDayAgo, end: Date(), options: .strictEndDate)
        
        let waterQuery = HKSampleQuery(sampleType: waterType,
                                       predicate: last24hPredicate,
                                       limit: HKObjectQueryNoLimit,
                                       sortDescriptors: nil) {
                                        (query, samples, error) in
                                        
                                        guard
                                            error == nil,
                                            let quantitySamples = samples as? [HKQuantitySample] else {
                                                print("Something went wrong: \(String(describing: error))")
                                                return
                                        }
                                        
                                        let total = quantitySamples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: HKUnit.literUnit(with: .milli)) }
                                        print("total water: \(total)")
                                        DispatchQueue.main.async {
                                            self.waterLabel.text = String(format: "Water: %.1f lts", total)
                                        }
        }
        HKHealthStore().execute(waterQuery)
    }
    
    func readHeight(){

        let heightType = HKSampleType.quantityType(forIdentifier: HKQuantityTypeIdentifier.height)!
        let query = HKSampleQuery(sampleType: heightType, predicate: nil, limit: 1, sortDescriptors: nil) { (query, results, error) in
            if let result = results?.first as? HKQuantitySample{
                DispatchQueue.main.async {
                    //Sync with main thread
                    self.heightLabel.text = "Height: \(result.quantity)"
                }
                
                print("Height: \(result.quantity)")
            }else{
                print("Something went wrong: \(String(describing: error))")
            }
        }
        HKHealthStore().execute(query)
    }
    
    func readWeight(){
        
        let weightType = HKSampleType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bodyMass)!
        let query = HKSampleQuery(sampleType: weightType, predicate: nil, limit: 1, sortDescriptors: nil) { (query, results, error) in
            if let result = results?.first as? HKQuantitySample{
                DispatchQueue.main.async {
                    //Sync with main thread
                    self.weightLabel.text = "Weight: \(result.quantity)"
                }
                print("Weight: \(result.quantity)")
            }else{
                print("Something went wrong: \(String(describing: error))")
            }
        }
        HKHealthStore().execute(query)
    }
    
    
    @IBAction func writeWater(_ sender: Any) {
        guard let waterType = HKSampleType.quantityType(forIdentifier: .dietaryWater) else {
            print("Sample type not available")
            return
        }
        
        let waterQuantity = HKQuantity(unit: HKUnit.literUnit(with: .milli), doubleValue: 200.0)
        let today = Date()
        let waterQuantitySample = HKQuantitySample(type: waterType, quantity: waterQuantity, start: today, end: today)
        
        HKHealthStore().save(waterQuantitySample) { (success, error) in
            self.readWater()
        }
    }
}

extension Date {
    var oneDayAgo: Date {
        return self.addingTimeInterval(-86400)
    }
}
