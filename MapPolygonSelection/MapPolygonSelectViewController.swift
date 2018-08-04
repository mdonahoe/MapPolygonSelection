//
//  MapPolygonSelectViewController
//  MapPolygonSelection
//
//  Created by Matt Donahoe on 4/15/18.
//
import MapKit
import UIKit

class MapPolygonSelectViewController: UIViewController, MKMapViewDelegate {

  @IBOutlet weak var mapView: MKMapView!

  var points : [MKPointAnnotation] = []
  var polygon : MKPolygon?

  override func viewDidLoad() {
    super.viewDidLoad()

    // Set a default location, though real code should use device GPS

    // Center map on Honolulu
    let lat = 21.282778
    let lon = -157.829443
    let initialLocation = CLLocation(latitude: lat, longitude: lon)
    centerMapOnLocation(location: initialLocation)

    // Create some annotations around the center point
    let d = 0.001
    var locations : [CLLocation] = []
    locations.append(CLLocation(latitude: lat - d, longitude: lon - d))
    locations.append(CLLocation(latitude: lat + d, longitude: lon - d))
    locations.append(CLLocation(latitude: lat + d, longitude: lon + d))
    locations.append(CLLocation(latitude: lat - d, longitude: lon + d))
    for loc in locations {
      let point = MKPointAnnotation()
      points.append(point)
      point.coordinate = loc.coordinate
      mapView.addAnnotation(point)
    }
    updatePolygon()
  }

  func updatePolygon() {
    // Remove the existing polygon from the map.
    if polygon != nil {
      mapView.remove(polygon!)
    }
    // Create a new polygon from the coordinates of the annotation
    let coords = points.map { $0.coordinate }
    polygon = MKPolygon(coordinates: coords, count: points.count)
    mapView.add(polygon!)
  }

  let regionRadius: CLLocationDistance = 1000  // [m]
  func centerMapOnLocation(location: CLLocation) {
    let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate,
                                                              regionRadius, regionRadius)
    mapView.setRegion(coordinateRegion, animated: true)
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  // MARK: MKMapViewDelegate methods

  func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    if overlay is MKPolygon {
      let polygonView = MKPolygonRenderer(overlay: overlay)
      polygonView.strokeColor = UIColor.green
      polygonView.lineWidth = 1.0
      polygonView.fillColor = UIColor()
      polygonView.fillColor = UIColor.green.withAlphaComponent(0.25)
      return polygonView
    }
    return MKOverlayRenderer()
  }

  let reuseIdentifier = "marker"
  func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
    guard let annotation = annotation as? MKPointAnnotation else { return nil }
    var view = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier);
    if view == nil {
      view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)
      view?.canShowCallout = false
      // Override the drag logic with our own handler
      // from https://stackoverflow.com/a/39374717/53997
      view?.isDraggable = false
      let drag = UILongPressGestureRecognizer(target: self, action: #selector(handleDrag(gesture:)))
      drag.minimumPressDuration = 0 // set this to whatever you want
      drag.allowableMovement = .greatestFiniteMagnitude
      view?.addGestureRecognizer(drag)
    } else {
      view?.annotation = annotation
    }
    return view
  }

  // NOTE(matt): This normally gets called when the map handles view dragging.
  // However, we've bypassed that by set isDraggable = False and using a custom handler instead.
  func mapView(_ mapView: MKMapView,
               annotationView view: MKAnnotationView,
               didChange newState: MKAnnotationViewDragState,
               fromOldState oldState: MKAnnotationViewDragState) {
    // The marker got dragged, recreate a polygon
    updatePolygon()
  }

  // MARK: Touch Handling

  // TODO(matt): make this a map from MKAnnotationView to CLLocationCoordinate2D.
  // Otherwise, multi-touch dragging causes jumps.
  private var startLocation = CGPoint.zero

  // Custom drag handler for MKAnnotationViews
  // from https://stackoverflow.com/a/39374717/53997
  @objc func handleDrag(gesture: UILongPressGestureRecognizer) {
    let annotationView = gesture.view as! MKAnnotationView
    annotationView.setSelected(false, animated: false)
    let location = gesture.location(in: mapView)
    if gesture.state == .began {
      startLocation = location
    } else if gesture.state == .changed {
      gesture.view?.transform = CGAffineTransform(translationX: location.x - startLocation.x, y: location.y - startLocation.y)
    } else if gesture.state == .ended || gesture.state == .cancelled {
      let annotation = annotationView.annotation as! MKPointAnnotation
      let translate = CGPoint(x: location.x - startLocation.x, y: location.y - startLocation.y)
      let originalLocation = mapView.convert(annotation.coordinate, toPointTo: mapView)
      let updatedLocation = CGPoint(x: originalLocation.x + translate.x, y: originalLocation.y + translate.y)
      annotationView.transform = CGAffineTransform.identity
      annotation.coordinate = mapView.convert(updatedLocation, toCoordinateFrom: mapView)
      // We only update the polygon when the gesture ends.
      // TODO(matt): efficiently update the polygon all the time.
      updatePolygon()
    }
  }

}

