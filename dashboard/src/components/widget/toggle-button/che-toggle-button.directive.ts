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

/**
 * Defines a directive for a toggle button.
 * @author Florent Benoit
 */
export class CheToggleButton {

  /**
   * Default constructor that is using resource
   * @ngInject for Dependency injection
   */
  constructor () {
    this.restrict='E';
    this.templateUrl = 'components/widget/toggle-button/che-toggle-button.html';

    // scope values
    this.scope = {
      title:'@cheTitle',
      fontIcon: '@cheFontIcon',
      ngDisabled: '@ngDisabled'
    };

  }

  link($scope) {
    $scope.controller = $scope.$parent.$parent.cheToggleCtrl || $scope.$parent.$parent.$parent.cheToggleCtrl;
  }


}
