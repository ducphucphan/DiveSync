//
//  MKMapView+ZoomLevel.swift
//  DiveSync
//
//  Created by Phan Duc Phuc on 12/29/25.
//

import MapKit

private let MERCATOR_OFFSET: Double = 268435456
private let MERCATOR_RADIUS: Double = 85445659.44705395

extension MKMapView {

    // MARK: - Map conversion

    private func longitudeToPixelSpaceX(_ longitude: Double) -> Double {
        return round(MERCATOR_OFFSET + MERCATOR_RADIUS * longitude * .pi / 180.0)
    }

    private func latitudeToPixelSpaceY(_ latitude: Double) -> Double {
        return round(
            MERCATOR_OFFSET
            - MERCATOR_RADIUS
            * log((1 + sin(latitude * .pi / 180.0)) / (1 - sin(latitude * .pi / 180.0))) / 2.0
        )
    }

    private func pixelSpaceXToLongitude(_ pixelX: Double) -> Double {
        return ((round(pixelX) - MERCATOR_OFFSET) / MERCATOR_RADIUS) * 180.0 / .pi
    }

    private func pixelSpaceYToLatitude(_ pixelY: Double) -> Double {
        return (.pi / 2.0 - 2.0 * atan(exp((round(pixelY) - MERCATOR_OFFSET) / MERCATOR_RADIUS))) * 180.0 / .pi
    }

    // MARK: - Current zoom level

    var zoomLevel: Int {
        let region = self.region

        let centerPixelX = longitudeToPixelSpaceX(region.center.longitude)
        let topLeftPixelX = longitudeToPixelSpaceX(
            region.center.longitude - region.span.longitudeDelta / 2
        )

        let scaledMapWidth = (centerPixelX - topLeftPixelX) * 2
        let mapSizeInPixels = self.bounds.size
        let zoomScale = scaledMapWidth / Double(mapSizeInPixels.width)
        let zoomExponent = log2(zoomScale)
        let zoomLevel = 21 - zoomExponent

        return Int(round(zoomLevel))
    }

    // MARK: - Coordinate span for zoom level

    private func coordinateSpan(
        centerCoordinate: CLLocationCoordinate2D,
        zoomLevel: Int
    ) -> MKCoordinateSpan {

        let centerPixelX = longitudeToPixelSpaceX(centerCoordinate.longitude)
        let centerPixelY = latitudeToPixelSpaceY(centerCoordinate.latitude)

        let zoomExponent = 20 - zoomLevel
        let zoomScale = pow(2.0, Double(zoomExponent))

        let mapSizeInPixels = self.bounds.size
        let scaledMapWidth = Double(mapSizeInPixels.width) * zoomScale
        let scaledMapHeight = Double(mapSizeInPixels.height) * zoomScale

        let topLeftPixelX = centerPixelX - scaledMapWidth / 4
        let topLeftPixelY = centerPixelY - scaledMapHeight / 4

        let minLng = pixelSpaceXToLongitude(topLeftPixelX)
        let maxLng = pixelSpaceXToLongitude(topLeftPixelX + scaledMapWidth)
        let longitudeDelta = maxLng - minLng

        let minLat = pixelSpaceYToLatitude(topLeftPixelY)
        let maxLat = pixelSpaceYToLatitude(topLeftPixelY + scaledMapHeight)
        let latitudeDelta = -(maxLat - minLat)

        return MKCoordinateSpan(latitudeDelta: latitudeDelta,
                                longitudeDelta: longitudeDelta)
    }

    // MARK: - Public API

    func setCenterCoordinate(
        _ centerCoordinate: CLLocationCoordinate2D,
        zoomLevel: Int,
        animated: Bool
    ) {
        var zoom = zoomLevel
        zoom = min(zoom, 21)
        zoom = max(zoom, 1)

        let span = coordinateSpan(centerCoordinate: centerCoordinate, zoomLevel: zoom)
        let region = MKCoordinateRegion(center: centerCoordinate, span: span)
        setRegion(region, animated: animated)
    }

    func loadWorldMap() {
        let center = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let span = MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 360)
        let region = MKCoordinateRegion(center: center, span: span)
        setRegion(region, animated: false)
    }
}

