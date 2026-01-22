    //
    //  OwnerInfoCardViewBuilder.swift
    //  DiveSync
    //
    //  Created by Phan Duc Phuc on 1/9/26.
    //

    import UIKit

    // MARK: - Data Models

    public struct OwnerInfo {
        public let name: String
        public let phone: String
        public let email: String
        public let bloodType: String

        public init(
            name: String,
            phone: String,
            email: String,
            bloodType: String
        ) {
            self.name = name
            self.phone = phone
            self.email = email
            self.bloodType = bloodType
        }
    }

    public struct EmergencyContact {
        public let name: String
        public let phone: String

        public init(
            name: String,
            phone: String
        ) {
            self.name = name
            self.phone = phone
        }
    }

    // MARK: - View Builder

    public final class OwnerInfoCardViewBuilder {

        // MARK: Public API (ONLY thing you need)

        public static func build(
            owner: OwnerInfo,
            emergency: EmergencyContact,
            size: CGSize = CGSize(width: 240, height: 240)
        ) -> UIView {

            let container = UIView(frame: CGRect(origin: .zero, size: size))
            container.backgroundColor = .white

            let ownerHeader = makeHeaderLabel(
                text: "Owner Info".localized.uppercased(),
                background: UIColor(red: 1.0, green: 0.67, blue: 0.12, alpha: 1)
            )

            let ownerContent = makeContentView(
                text: ownerText(owner),
                background: UIColor(red: 0.23, green: 0.40, blue: 0.65, alpha: 1)
            )

            let emergencyHeader = makeHeaderLabel(
                text: "Emergency Contact".localized.uppercased(),
                background: UIColor(red: 1.0, green: 0.67, blue: 0.12, alpha: 1)
            )

            let emergencyContent = makeContentView(
                text: emergencyText(emergency),
                background: UIColor(red: 0.05, green: 0.40, blue: 0.45, alpha: 1)
            )

            let stack = UIStackView(arrangedSubviews: [
                ownerHeader,
                ownerContent,
                emergencyHeader,
                emergencyContent
            ])

            stack.axis = .vertical
            stack.spacing = 0
            stack.distribution = .fill
            stack.frame = container.bounds

            container.addSubview(stack)

            applyFixedHeights(
                ownerHeader: ownerHeader,
                ownerContent: ownerContent,
                emergencyHeader: emergencyHeader,
                emergencyContent: emergencyContent
            )

            return container
        }
    }

    // MARK: - Private Helpers

    private extension OwnerInfoCardViewBuilder {

        static func makeHeaderLabel(
            text: String,
            background: UIColor
        ) -> UILabel {
            let label = UILabel()
            label.text = text
            label.textAlignment = .center
            label.font = .boldSystemFont(ofSize: 20)
            label.textColor = .white
            label.backgroundColor = background
            label.translatesAutoresizingMaskIntoConstraints = false
            return label
        }

        static func makeContentLabel(
            text: String,
            background: UIColor
        ) -> UILabel {
            let label = UILabel()
            label.text = text
            label.numberOfLines = 0
            label.font = .systemFont(ofSize: 16)
            label.textColor = .white
            label.backgroundColor = background
            label.translatesAutoresizingMaskIntoConstraints = false
            label.textAlignment = .left
            label.setContentCompressionResistancePriority(.required, for: .vertical)
            return label
        }
        
        static func makeContentView(
            text: String,
            background: UIColor
        ) -> UIView {

            let container = UIView()
            container.backgroundColor = background
            container.translatesAutoresizingMaskIntoConstraints = false

            let label = UILabel()
            label.text = text
            label.numberOfLines = 0
            label.font = .systemFont(ofSize: 16)
            label.textColor = .white
            label.textAlignment = .left
            label.translatesAutoresizingMaskIntoConstraints = false

            container.addSubview(label)

            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
                label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
                label.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
                label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4)
            ])

            return container
        }

        static func ownerText(_ owner: OwnerInfo) -> String {
            let lines: [String] = [
                owner.name,
                owner.phone,
                owner.email,
                owner.bloodType.isEmpty ? nil : "Blood Type".localized + ": \(owner.bloodType)"
            ].compactMap { $0 } // loại bỏ nil
            return lines
                .compactMap { $0 }           // loại bỏ nil
                .filter { !$0.isEmpty }      // loại bỏ empty string
                .joined(separator: "\n")
        }
        
        static func emergencyText(_ emergency: EmergencyContact) -> String {
            let lines: [String] = [
                emergency.name,
                emergency.phone
            ].filter { !$0.isEmpty } // loại bỏ empty string
            return lines
                .compactMap { $0 }           // loại bỏ nil
                .filter { !$0.isEmpty }      // loại bỏ empty string
                .joined(separator: "\n")
        }

        static func applyFixedHeights(
            ownerHeader: UIView,
            ownerContent: UIView,
            emergencyHeader: UIView,
            emergencyContent: UIView
        ) {
            NSLayoutConstraint.activate([
                ownerHeader.heightAnchor.constraint(equalToConstant: 28),
                ownerContent.heightAnchor.constraint(equalToConstant: 120),
                emergencyHeader.heightAnchor.constraint(equalToConstant: 28),
                emergencyContent.heightAnchor.constraint(equalToConstant: 64)
            ])
        }
    }

