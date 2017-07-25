//
//  ViewController.swift
//  tracker
//
//  Created by Sírius Gomes on 09/07/17.
//  Copyright © 2017 Sírius Gomes. All rights reserved.
//

import UIKit
import MapKit
import CoreData


class ViewController: UIViewController, CLLocationManagerDelegate {
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var switchOnline: UISwitch!
    @IBOutlet weak var switchRecord: UISwitch!
    @IBOutlet weak var distanceTracked: UILabel!
    @IBOutlet weak var buttonDeleteSent: UIButton!
    @IBOutlet weak var altitudeLabel: UILabel!
    @IBOutlet weak var speedLabel: UILabel!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var enviadosLabel: UILabel!
    @IBOutlet weak var latLabel: UILabel!
    
    let locationManager = CLLocationManager()
    var enviados = 0
    var gravados = 0
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate

    
    @IBAction func onButtonDeleteSentClick(_ sender: UIButton) {
        deleteSentPositions()
    }
    
    @IBAction func onChangeDesiredAcuracy(_ sender: UISegmentedControl) {
        let accuracyValues = [
            kCLLocationAccuracyBest,
            kCLLocationAccuracyNearestTenMeters,
            kCLLocationAccuracyHundredMeters,
            kCLLocationAccuracyKilometer,
            kCLLocationAccuracyThreeKilometers,
            kCLLocationAccuracyBestForNavigation
        ]
        
        locationManager.desiredAccuracy = accuracyValues[sender.selectedSegmentIndex]
    }
    
    @IBAction func onChangeDistanceFilter(_ sender: UISegmentedControl) {
        
        let accuracyValues = [
            0,
            10,
            25,
            100,
            1000,
            5000]
        
        locationManager.distanceFilter = CLLocationDistance(accuracyValues[sender.selectedSegmentIndex]);
        
    }
    override func viewDidLoad() {

        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        appDelegate.enableUIChanges = true
        
        setCounters()
        
        mapView.mapType = MKMapType.hybridFlyover
        
        // Ask for Authorisation from the User.
        self.locationManager.requestAlwaysAuthorization()
        
        // For use in foreground
        self.locationManager.requestWhenInUseAuthorization()
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            //locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.distanceFilter = 10
            locationManager.activityType = CLActivityType.fitness
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.startUpdatingLocation()
        }
    }
    @IBAction func switchOnlineChange(_ sender: UISwitch) {
        if sender.isOn {
            print("switch online on")
            switchRecord.setOn(true, animated: true)
            appDelegate.enableOnline = true
            appDelegate.enableRecord = true
            sendPositions()
            setCounters()
        } else {
            appDelegate.enableOnline = false
            setCounters()
            print("switch online off")
        }
    }

    @IBAction func switchRecordChange(_ sender: UISwitch) {
        if sender.isOn {
            print("switch record on")
            appDelegate.enableRecord = true
        } else {
            appDelegate.enableRecord = false
            setCounters()
            print("switch record off")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let locValue:CLLocationCoordinate2D = manager.location!.coordinate
        print("Location = \(locValue.latitude),\(locValue.longitude) - Altitude: \(manager.location!.altitude)m - Speed: \(manager.location!.speed)m/s - Timestamp: \(manager.location!.timestamp)")
       
        latLabel.text = "Latitude/Longitude: \(NSString(format: "%.6f",locValue.latitude)),\(NSString(format: "%.6f",locValue.longitude))"
        altitudeLabel.text = "Altitude: \(NSString(format: "%.2f", manager.location!.altitude))m"
        speedLabel.text = "Speed: \(NSString(format: "%.2f", manager.location!.speed * 3.6))km/h"
        
        // Coloca o pin no mapa..
        if (appDelegate.enableUIChanges) {
            mapView.removeAnnotations(mapView.annotations)
            let annotation = MKPointAnnotation()
            annotation.title = "Current location"
            annotation.coordinate = CLLocationCoordinate2D(latitude: locValue.latitude, longitude: locValue.longitude)
            mapView.addAnnotation(annotation)
            mapView.setCenter(annotation.coordinate, animated: true)
        }
        
        // Salva no Coredata
        if appDelegate.enableRecord {
            savePosition(latitude: locValue.latitude, longitude: locValue.longitude, timestamp: manager.location!.timestamp, speed: manager.location!.speed)
        }
        
        if appDelegate.enableOnline {
            sendPositions()
        }
        
        setCounters()
        
    }
    
//    func getContext () -> NSManagedObjectContext {
//        let appDelegate = UIApplication.shared.delegate as! AppDelegate
//        return appDelegate.persistentContainer.viewContext
//    }
    
    func savePosition(latitude: Double, longitude: Double, timestamp: Date, speed: Double) {
        let context = appDelegate.persistentContainer.viewContext
        
        //retrieve the entity that we just created
        let entity =  NSEntityDescription.entity(forEntityName: "Position", in: context)
        
        let transc = NSManagedObject(entity: entity!, insertInto: context)
        
        //set the entity values
        transc.setValue(latitude, forKey: "latitude")
        transc.setValue(longitude, forKey: "longitude")
        transc.setValue(timestamp, forKey: "timestamp")
        transc.setValue(speed, forKey: "speed")
        transc.setValue(false, forKey: "sent")
        
        //save the object
        do {
            try context.save()
            print("saved!")
        } catch let error as NSError  {
            print("Could not save \(error), \(error.userInfo)")
        } catch {
            
        }
    }
    
    func setCounters() {
        if (appDelegate.enableUIChanges) {
            gravados = 0
            enviados = 0
            var distance = CLLocationDistance()
            //create a fetch request, telling it about the entity
            let fetchRequest: NSFetchRequest<Position> = Position.fetchRequest()
            //fetchRequest.predicate = NSPredicate(format: "sent == %@", firstName)
            //distanceTracked
            do {
                let searchResults = try appDelegate.persistentContainer.viewContext.fetch(fetchRequest)
                
                var locActual = CLLocation()
                var locPrevious = CLLocation()
                
                for trans in searchResults as [NSManagedObject] {
                    locActual = CLLocation.init(latitude: trans.value(forKey: "latitude") as! Double, longitude: trans.value(forKey: "longitude") as! Double)
                    if (gravados > 0) {
                        distance.add(locActual.distance(from: locPrevious))
                    }
                    gravados+=1
                    if trans.value(forKey: "sent") as! Bool == true {
                        enviados+=1
                    }
                    locPrevious = CLLocation.init(latitude: trans.value(forKey: "latitude") as! Double, longitude: trans.value(forKey: "longitude") as! Double)
                }
            }
            catch {
                print("Error with request: \(error)")
            }
            self.enviadosLabel.text = "\(self.gravados)/\(self.enviados)"
            self.distanceTracked.text = "Traveled: \(NSString(format: "%.2f", (distance / 1000)))km"
        }
    }
    
    func deleteSentPositions() {
        let context = appDelegate.persistentContainer.viewContext

        //create a fetch request, telling it about the entity
        let fetchRequest: NSFetchRequest<Position> = Position.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "sent == %@", NSNumber(booleanLiteral: true))
        
        do {
            let searchResults = try appDelegate.persistentContainer.viewContext.fetch(fetchRequest)
            
            print ("Number of positions to delete: \(searchResults.count)")
            
            for trans in searchResults as [NSManagedObject] {
                context.delete(trans)
            }
            do {
                try context.save()
                print("saved!")
            } catch let error as NSError  {
                print("Could not save \(error), \(error.userInfo)")
            } catch {
                
            }
        }
        catch {
            print("Error with request: \(error)")
        }
        setCounters()
    }

    func sendPositions() {
        //create a fetch request, telling it about the entity
        let fetchRequest: NSFetchRequest<Position> = Position.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "sent == %@", NSNumber(booleanLiteral: false))
        
        do {
            //go get the results
            let searchResults = try appDelegate.persistentContainer.viewContext.fetch(fetchRequest)
            
            //I like to check the size of the returned results!
            print ("Number of positions to send: \(searchResults.count)")
            
            // Semaphore to avoid the for to open countless threads with no control. Let's allow 16 at a time..
            let dispatchQueue = DispatchQueue(label: "DispatchQueue.sendPositions")
            let semaphore = DispatchSemaphore(value: 16)
            dispatchQueue.async {
                
                //You need to convert to NSManagedObject to use 'for' loops
                for trans in searchResults as [NSManagedObject] {
                    
                    _ = semaphore.wait(timeout: DispatchTime.distantFuture)
                    
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZ"
                    dateFormatter.timeZone = NSTimeZone(abbreviation: "UTC")! as TimeZone
                    let todaysDate = dateFormatter.string(from: trans.value(forKey: "timestamp") as! Date)
                    
                    var success = false
                    
                    var request = URLRequest(url: URL(string: "http://tracker.siriusgomes.com.br/index.php")!)
                    request.httpMethod = "POST"
                    let postString = "lat=\(trans.value(forKey: "latitude") ?? "")&lng=\(trans.value(forKey: "longitude") ?? "")&date=\(todaysDate)&speed=\(trans.value(forKey: "speed") ?? "")"
                    print ("Sending \(postString)")
                    request.httpBody = postString.data(using: .utf8)
                    let task = URLSession.shared.dataTask(with: request) { data, response, error in
                        guard let data = data, error == nil else {                                                 // check for fundamental networking error
                            print("error=\(String(describing: error))")
                            return
                        }
                        
                        if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {           // check for http errors
                            print("statusCode should be 200, but is \(httpStatus.statusCode)")
                            print("response = \(String(describing: response))")
                            success = false
                        }
                        else {
                            let responseString = String(data: data, encoding: .utf8)
                            print("response = \(responseString == "1" ? "OK" : "")")
                            success = (responseString == "1" ? true : false)
                        }
                        if success == true {
                            trans.setValue(true, forKey: "sent")
                            do {
                                try self.appDelegate.persistentContainer.viewContext.save()
                                print("Updated sent to true!")
                                if self.appDelegate.enableOnline {
                                    DispatchQueue.main.async {
                                        self.setCounters()
                                    }
                                }
                                else if (self.appDelegate.enableUIChanges) {
                                    DispatchQueue.main.async {
                                        self.enviados += 1
                                        self.enviadosLabel.text = "\(self.gravados)/\(self.enviados)"
                                    }
                                }
                                semaphore.signal()
                            } catch let error as NSError  {
                                print("Could not save \(error), \(error.userInfo)")
                            } catch {
                            }
                        }
                        
                        
                    }
                    task.resume()
                    
                }
            }
            
        } catch {
            print("Error with request: \(error)")
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

