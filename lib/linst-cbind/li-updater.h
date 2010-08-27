/* -*- Mode: C; tab-width: 8; indent-tabs-mode: t; c-basic-offset: 8 -*-
 *
 * Copyright (C) 2010 Matthias Klumpp <matthias@nlinux.org>
 *
 * Licensed under the GNU General Public License Version 3
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#if !defined (__LISTALLER_H_INSIDE__)
#error "Only <listaller.h> can be included directly."
#endif

#ifndef __LI_UPDATER
#define __LI_UPDATER

#include<stdio.h>
#include<iostream>


void* li_updater_new(void);

void li_updater_free(void* upd);

void li_updater_set_sumode(void* upd,bool val);

bool li_updater_register_status_call(void* upd,StatusChangeEvent call,void* user_data);

bool li_updater_register_request_call(void* upd,UserRequestCall call,void* user_data);

bool li_updater_register_newupdate_call(void* upd,NewUpdateEvent call,void* user_data);

bool li_updater_search_updates(void* upd);

char *li_updater_updateid_oldversion(void* upd,int uid);

char *li_updater_updateid_newversion(void* upd,int uid);


#endif /* __LI_UPDATER */
