/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

import Foundation

protocol ViewModelProtocol {
    var components: ControllerComponents { get }
}

protocol ComponentsInitializable: ViewModelProtocol {
    init(components: ControllerComponents)
}

protocol ViewModelController: class {
    func initialize(with value: Any?, source: UIViewController?)
}

protocol ViewModelControllerEx: ViewModelController, ControllerComponentsInjectable {
    associatedtype ViewModelEx: ViewModelProtocol

    var viewModel: ViewModelEx? { get set }

    func observe(viewModel: ViewModelEx)
}

extension ViewModelControllerEx {
    func initialize(with value: Any?, source: UIViewController?) {
        if let viewModel = value as? ViewModelEx {
            self.viewModel = viewModel
        } else if let componets = (source as? ControllerComponentsInjectable)?.controllerComponents {
            if let type = (ViewModelEx.self as? ComponentsInitializable.Type) {
                let viewModel = type.init(components: componets) as? ViewModelEx
                self.viewModel = viewModel
            }
        } else {
            assert(false)
        }
    }

    var controllerComponents: ControllerComponents? {
        get {
            return viewModel?.components
        }
        set {
            assert(false, "Not supported")
        }
    }
}
