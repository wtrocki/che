/*
 * Copyright (c) 2015-2016 Codenvy, S.A.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *
 * Contributors:
 *   Codenvy, S.A. - initial API and implementation
 */
'use strict';
import {ListComponentsController} from "../list-components.controller";

/**
 * @ngdoc controller
 * @name list.components.controller:AddComponentDialogController
 * @description This class is handling the controller for a dialog box about adding a stack's component.
 * @author Oleksii Orel
 */
export class AddComponentDialogController {
  $mdDialog: ng.material.IDialogService;

  name: string;
  version: string;
  components: Array<any>;
  usedComponentsName: Array<string>;
  callbackController: ListComponentsController;

  /**
   * Default constructor that is using resource
   * @ngInject for Dependency injection
   */
  constructor($mdDialog: ng.material.IDialogService) {
    this.$mdDialog = $mdDialog;

    this.usedComponentsName = [];
    this.components.forEach((component) => {
      this.usedComponentsName.push(component.name);
    });
  }

  /**
   * Check if the name is unique.
   * @param name
   * @returns {boolean}
   */
  isUnique(name: string): boolean {
    return this.usedComponentsName.indexOf(name) === -1;
  }

  /**
   * It will hide the dialog box.
   */
  hide(): void {
    this.$mdDialog.hide();
  }

  /**
   * Add a new component
   */
  addComponent(): void {
    this.callbackController.addComponent(this.name, this.version);
    this.hide();
  }
}
