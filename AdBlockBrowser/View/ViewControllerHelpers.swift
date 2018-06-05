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

import UIKit

class ViewController<ViewModel: ViewModelProtocol>:
    UIViewController, ViewModelControllerEx {
    typealias ViewModelEx = ViewModel

    var viewModel: ViewModel?

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        _prepare(controller: self, for: segue, sender: sender)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        _viewDidLoad(controller: self)
    }

    func observe(viewModel: ViewModelEx) {
    }
}

class TableViewController<ViewModel: ViewModelProtocol>:
    UITableViewController, ViewModelControllerEx {
    typealias ViewModelEx = ViewModel

    var viewModel: ViewModel?

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        _prepare(controller: self, for: segue, sender: sender)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        _viewDidLoad(controller: self)
    }

    func observe(viewModel: ViewModelEx) {
    }
}

class CollectionViewController<ViewModel: ViewModelProtocol>:
    UICollectionViewController, ViewModelControllerEx {
    typealias ViewModelEx = ViewModel

    var viewModel: ViewModel?

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        _prepare(controller: self, for: segue, sender: sender)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        _viewDidLoad(controller: self)
    }

    func observe(viewModel: ViewModelEx) {
    }
}

private func _prepare<T>(controller this: T, for segue: UIStoryboardSegue, sender: Any?)
    where T: UIViewController, T: ViewModelController & ControllerComponentsInjectable {
    if let controller = segue.destination as? ViewModelController {
        controller.initialize(with: sender, source: segue.source)
    } else if let controller = (segue.destination as? UINavigationController)?.topViewController {
        if let controller = controller as? ViewModelController {
            controller.initialize(with: sender, source: segue.source)
        } else {
            this.tryInjectToController(controller)
        }
    } else {
        this.tryInjectToController(segue.destination)
    }
}

private func _viewDidLoad<T>(controller this: T)
    where T: UIViewController, T: ViewModelControllerEx {
    assert(this.viewModel != nil)
    if let viewModel = this.viewModel {
        this.observe(viewModel: viewModel)
    }
}
