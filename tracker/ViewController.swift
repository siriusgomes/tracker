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
    
 
    @IBOutlet weak var swithEnvio: UISwitch!
    
    let locationManager = CLLocationManager()
   
    @IBOutlet weak var speedKmhLabel: UILabel!
    @IBOutlet weak var altitudeLabel: UILabel!
    @IBOutlet weak var speedLabel: UILabel!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var enviadosLabel: UILabel!
    @IBOutlet weak var lngLabel: UILabel!
    @IBOutlet weak var latLabel: UILabel!
    var enviados = 0
    var gravados = 0
    
    @IBAction func onChangeSegmentedControl(_ sender: UISegmentedControl) {
        
        let accuracyValues = [
            10,
            1000,
            5000]
        
        locationManager.distanceFilter = CLLocationDistance(accuracyValues[sender.selectedSegmentIndex]);
        
    }
    override func viewDidLoad() {
        
        
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        mapView.mapType = MKMapType.satelliteFlyover
        
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
        
        swithEnvio.addTarget(self, action: #selector(ViewController.sampleSwitchValueChanged(sender:)), for: UIControlEvents.valueChanged)
        
    }
    
    func sampleSwitchValueChanged(sender: UISwitch!)
    {
        if sender.isOn {
            print("switch on")
            sendPositions()
        } else {
            
        }
    }

    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let locValue:CLLocationCoordinate2D = manager.location!.coordinate
        print("locations = \(locValue.latitude) \(locValue.longitude)")
        lngLabel.text = "\(NSString(format: "%.6f",locValue.longitude))"
        latLabel.text = "\(NSString(format: "%.6f",locValue.latitude))"
        altitudeLabel.text = "\(NSString(format: "%.2f", manager.location!.altitude))"
        speedLabel.text = "\(NSString(format: "%.2f", manager.location!.speed)) m/s"
        speedKmhLabel.text = "\(NSString(format: "%.2f", manager.location!.speed * 3.6)) km/h"
        print("Altitude: \(manager.location!.altitude) m")
        print("Speed: \(manager.location!.speed)")
        print("Timestamp: \(manager.location!.timestamp)")

        
        // Coloca o pin no mapa..
        mapView.removeAnnotations(mapView.annotations)
        let annotation = MKPointAnnotation()
        annotation.title = "eh nois!"
        annotation.coordinate = CLLocationCoordinate2D(latitude: locValue.latitude, longitude: locValue.longitude)
        mapView.addAnnotation(annotation)
        mapView.centerCoordinate = annotation.coordinate
        
        
        // Salva no Coredata
        savePosition(latitude: locValue.latitude, longitude: locValue.longitude, timestamp: manager.location!.timestamp)
        
        gravados+=1
        enviadosLabel.text = "\(enviados) / \(gravados)"
        
    }
    
    func getContext () -> NSManagedObjectContext {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        return appDelegate.persistentContainer.viewContext
    }
    
    func savePosition(latitude: Double, longitude: Double, timestamp: Date) {
        let context = getContext()
        
        //retrieve the entity that we just created
        let entity =  NSEntityDescription.entity(forEntityName: "Position", in: context)
        
        let transc = NSManagedObject(entity: entity!, insertInto: context)
        
        //set the entity values
        transc.setValue(latitude, forKey: "latitude")
        transc.setValue(longitude, forKey: "longitude")
        transc.setValue(timestamp, forKey: "timestamp")
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
    
    
    func sendPositions() {
        gravados = 0
        enviados = 0
        //create a fetch request, telling it about the entity
        let fetchRequest: NSFetchRequest<Position> = Position.fetchRequest()
        
        do {
            //go get the results
            let searchResults = try getContext().fetch(fetchRequest)
            
            //I like to check the size of the returned results!
            print ("num of results = \(searchResults.count)")
            
            //You need to convert to NSManagedObject to use 'for' loops
            for trans in searchResults as [NSManagedObject] {
                gravados+=1
                if trans.value(forKey: "sent") as! Bool == false {
                    
                
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd hh:mm:ss"
                    let todaysDate = dateFormatter.string(from: trans.value(forKey: "timestamp") as! Date)
                    
                    print ("Sending \(trans.value(forKey: "latitude") ?? ""), \(trans.value(forKey: "longitude") ?? "")")
                    var success = false
                    
                    var request = URLRequest(url: URL(string: "http://tracker.siriusgomes.com.br/index.php")!)
                    request.httpMethod = "POST"
                    let postString = "lat=\(trans.value(forKey: "latitude") ?? "")&lng=\(trans.value(forKey: "longitude") ?? "")&date=\(todaysDate)"
                    request.httpBody = postString.data(using: .utf8)
                    let task = URLSession.shared.dataTask(with: request) { data, response, error in
                        guard let data = data, error == nil else {                                                 // check for fundamental networking error
                            print("error=\(String(describing: error))")
                            return
                        }
                        
                        if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {           // check for http errors
                            print("statusCode should be 200, but is \(httpStatus.statusCode)")
                            print("response = \(String(describing: response))")
                        }
                        else {
                            success = true
                            
                        }
                        
                        let responseString = String(data: data, encoding: .utf8)
                        print("responseString = \(String(describing: responseString))")
                        
                        if success == true {
                            trans.setValue(true, forKey: "sent")
                            do {
                                try self.getContext().save()
                                print("Updated!")
                                self.enviadosLabel.text = "\(self.enviados) / \(self.gravados)"
                                self.enviados += 1
                            } catch let error as NSError  {
                                print("Could not save \(error), \(error.userInfo)")
                            } catch {
                            }
                        }
                        
                       
                    }
                    task.resume()
                
                
                    
                }
                else {
                    //get the Key Value pairs (although there may be a better way to do that...
                    print("Latitude: \(trans.value(forKey: "latitude") ?? "")")
                    print("Longitude: \(trans.value(forKey: "longitude") ?? "")")
                    print("Sent: \(trans.value(forKey: "sent") ?? "")")
                    self.enviados+=1
                }
                
                enviadosLabel.text = "\(enviados) / \(gravados)"
                
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

