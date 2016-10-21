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
package org.eclipse.che.plugin.gdb.server.parser;

import org.eclipse.che.api.debug.shared.model.Location;
import org.eclipse.che.api.debug.shared.model.impl.LocationImpl;
import org.eclipse.che.plugin.gdb.server.exception.GdbParseException;

import java.util.HashMap;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * 'backtrace' command parser.
 *
 * @author Roman Nikitenko
 */
public class GdbBacktrace {

    private static final Pattern GDB_FILE_LOCATION    = Pattern.compile("^([0-9]*) .* at (.*):([0-9]*).*", Pattern.DOTALL);
    private static final Pattern GDB_LIBRARY_LOCATION = Pattern.compile("^([0-9]*) .* from (.*)", Pattern.DOTALL);

    private final Map<Integer, Location> frames;

    public GdbBacktrace(Map<Integer, Location> frames) {
        this.frames = frames;
    }

    public Map<Integer, Location> getFrames() {
        return frames;
    }

    /**
     * Factory method.
     */
    public static GdbBacktrace parse(GdbOutput gdbOutput) throws GdbParseException {
        Matcher matcher;
        String output = gdbOutput.getOutput();
        String[] framesInfo = output.split("#");
        Map<Integer, Location> frames = new HashMap<>(framesInfo.length);

        for (String frame : framesInfo) {
            try {
                matcher = GDB_FILE_LOCATION.matcher(frame);
                if (matcher.find()) {
                    String fileLocation = matcher.group(2);
                    int lineNumber = Integer.parseInt(matcher.group(3));
                    int frameNumber = Integer.parseInt(matcher.group(1));

                    Location location = new LocationImpl(fileLocation, lineNumber);
                    frames.put(frameNumber, location);
                    continue;
                }

                matcher = GDB_LIBRARY_LOCATION.matcher(frame);
                if (matcher.find()) {
                    int frameNumber = Integer.parseInt(matcher.group(1));
                    String libraryLocation = matcher.group(2);
                    Location location = new LocationImpl(libraryLocation);
                    frames.put(frameNumber, location);
                }

            } catch (NumberFormatException e) {
                //we can't get info about current frame, but we are trying to get info about another frames
            }
        }

        if (!frames.isEmpty()) {
             return new GdbBacktrace(frames);
        }

        throw new GdbParseException(GdbBacktrace.class, output);
    }
}
