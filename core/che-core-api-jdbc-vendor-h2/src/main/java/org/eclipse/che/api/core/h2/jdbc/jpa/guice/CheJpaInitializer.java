/*******************************************************************************
 * Copyright (c) 2012-2016 Codenvy, S.A.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *
 * Contributors:
 *   Codenvy, S.A. - initial API and implementation
 *******************************************************************************/
package org.eclipse.che.api.core.h2.jdbc.jpa.guice;

import com.google.inject.persist.PersistService;

import org.eclipse.che.api.core.jdbc.jpa.guice.JpaInitializer;

import javax.inject.Inject;
import javax.inject.Named;
import javax.inject.Singleton;
import java.nio.file.Paths;

/**
 * Provides H2 specific initialization of persistent engine.
 *
 * @author Anton Korneta.
 */
@Singleton
public class CheJpaInitializer extends JpaInitializer {

    @Inject
    @Named("che.database")
    private String storageRoot;

    @Inject
    @Override
    public void init(PersistService persistService) {
        System.setProperty("h2.baseDir", Paths.get(storageRoot).resolve("db").toString());
        super.init(persistService);
    }
}
